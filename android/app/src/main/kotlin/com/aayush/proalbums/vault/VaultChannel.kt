package com.aayush.proalbums.vault

import android.app.Activity
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Intent
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.net.Uri
import android.os.PersistableBundle
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * The private vault's keys (phase 1): create the vault (DEK + Recovery Key),
 * PIN + security answers, unlock / lock. Hiding, the grid, video and
 * restore come in later phases on top of this.
 *
 * While unlocked the DEK lives ONLY here (native memory), never in Dart;
 * [lock] wipes it. Slow work (key derivation, files) runs on a worker
 * thread; answers come back on the main thread.
 */
class VaultChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val folder = VaultFolder(activity.contentResolver)
    private val stateFile = File(activity.filesDir, "vault/state.bin")

    /** The DEK while the vault is unlocked; null when locked. */
    @Volatile
    private var session: ByteArray? = null

    /** Also used to send Hide progress back to Dart. */
    private var channel: MethodChannel? = null
    private val hider = VaultHider(activity.contentResolver, folder)
    private val viewer = VaultViewer(activity.contentResolver, folder)
    private val restorer = VaultRestorer(activity.contentResolver, folder)
    private val importer = VaultImporter(activity.contentResolver, folder)

    /** Restore: the folder picker's answer, and what the picked folder holds. */
    private var pendingPick: MethodChannel.Result? = null
    private var picked: VaultImporter.Picked? = null
    private val videos = VaultVideoServer(activity.contentResolver, folder) { session?.copyOf() }

    /** Grid / viewer reads: their own threads, so thumbnails never wait
     * behind a big picture or a Hide. */
    private val readers = Executors.newFixedThreadPool(2)

    /** Hide waiting for the system delete request (originals). */
    private var pendingHide: List<VaultHider.Hidden>? = null
    private var pendingHideTotal = 0
    private var pendingHideResult: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> run(result) { status() }
            "create" -> run(result) { create() }
            "confirmRecoveryKeySaved" -> run(result) {
                state().recoveryKeySaved = true
                null
            }
            "unlockWithoutPassword" -> run(result) { unlockWithoutPassword() }
            "unlockAfterBiometric" -> run(result) { unlockFromState() }
            "lock" -> {
                lock()
                result.success(null)
            }
            "setPinAndAnswers" -> run(result) {
                setPinAndAnswers(call.argument("pin")!!, call.argument("answers")!!)
            }
            "verifyPin" -> run(result) { verifyPin(call.argument("pin")!!) }
            "verifyAnswers" -> run(result) { verifyAnswers(call.argument("answers")!!) }
            "setPinWithAnswers" -> run(result) {
                setPinWithAnswers(call.argument("answers")!!, call.argument("pin")!!)
            }
            "setPinWithRecoveryKey" -> run(result) {
                setPinWithRecoveryKey(call.argument("recoveryKey")!!, call.argument("pin")!!)
            }
            "setPasswordEnabled" -> run(result) {
                setPasswordEnabled(call.argument("enabled")!!)
            }
            "setSecure" -> {
                setSecure(call.argument("secure")!!)
                result.success(null)
            }
            "copySensitive" -> {
                copySensitive(call.argument("text")!!)
                result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            }
            "reset" -> run(result) { reset() }
            "count" -> run(result) { folder.countItems() }
            "list" -> run(result) { withSession { viewer.list(it) } }
            "thumbnail" -> read(result) {
                withSession { dek -> viewer.thumbnail(call.argument<String>("id")!!.toLong(), dek) }
            }
            "picture" -> read(result) {
                withSession { dek ->
                    viewer.picture(
                        call.argument<String>("id")!!.toLong(),
                        dek,
                        call.argument<Int>("maxLongEdge")!!,
                    )
                }
            }
            "restore" -> run(result) {
                restore(call.argument("ids")!!, call.argument("toTrash") ?: false)
            }
            "deleteForGood" -> run(result) { deleteForGood(call.argument("ids")!!) }
            "pickVaultFolder" -> pickVaultFolder(result)
            "importFromFolder" -> run(result) {
                importFromFolder(call.argument("recoveryKey")!!)
            }
            "videoUrl" -> run(result) {
                withSession { videos.urlFor(call.argument<String>("id")!!.toLong()) }
            }
            "details" -> read(result) {
                withSession { dek -> viewer.details(call.argument<String>("id")!!.toLong(), dek) }
            }
            "hide" -> hide(call, result)
            "biometricAvailable" -> result.success(biometricAvailable())
            "authenticateBiometric" -> authenticateBiometric(
                call.argument("title")!!,
                call.argument("usePassword")!!,
                result,
            )
            else -> result.notImplemented()
        }
    }

    /** Like [run], on the reader threads; a failure answers null (the
     * tile / viewer just shows nothing). */
    private fun read(result: MethodChannel.Result, work: () -> Any?) {
        readers.execute {
            val value = try {
                work()
            } catch (error: Exception) {
                null
            }
            main.post { result.success(value) }
        }
    }

    /** [work] with a COPY of the vault key (wiped after); locked = error. */
    private fun <T> withSession(work: (ByteArray) -> T): T {
        val dek = session?.copyOf() ?: throw VaultStateException("locked", "Unlock first")
        try {
            return work(dek)
        } finally {
            VaultCrypto.wipe(dek)
        }
    }

    /** Runs [work] on the worker; its value (or error) goes back to Dart. */
    private fun run(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                // Unit (no answer) cannot cross the channel: send null.
                val value = work().takeUnless { it is Unit }
                main.post { result.success(value) }
            } catch (error: VaultFormatException) {
                main.post { result.error("vault_format", error.message, null) }
            } catch (error: VaultStateException) {
                main.post { result.error(error.code, error.message, null) }
            } catch (error: Exception) {
                main.post { result.error("vault_failed", error.message, null) }
            }
        }
    }

    private fun state(): VaultState = VaultState.load(stateFile)

    private fun status(): Map<String, Any> {
        val state = state()
        return mapOf(
            "created" to state.created,
            "passwordEnabled" to state.passwordEnabled,
            "hasPin" to state.hasPin,
            "recoveryKeySaved" to state.recoveryKeySaved,
            "unlocked" to (session != null),
            "waitMillis" to state.waitMillis(),
        )
    }

    /**
     * The first Hide: a new DEK, its locked copy in the vault folder
     * (vault.key, Recovery Key) and on this phone (Keystore). Returns the
     * Recovery Key — shown ONCE, never stored anywhere.
     */
    private fun create(): String {
        val state = state()
        if (state.created) throw VaultStateException("already_created", "Vault exists")
        val dek = VaultCrypto.newKey()
        val recoveryKey = RecoveryKey.generate()
        folder.create(VaultFolder.KEY_FILE, VaultKeyFile.create(dek, recoveryKey))
        state.setDek(dek)
        replaceSession(dek)
        return recoveryKey
    }

    private fun unlockWithoutPassword(): Boolean {
        val state = state()
        if (state.passwordEnabled) throw VaultStateException("password_needed", "PIN needed")
        return unlockFromState(state)
    }

    private fun unlockFromState(state: VaultState = state()): Boolean {
        val dek = state.dek() ?: return false
        replaceSession(dek)
        return true
    }

    private fun setPinAndAnswers(pin: String, answers: List<String>) {
        requirePin(pin)
        require(answers.size == 2 && answers.all { it.isNotEmpty() }) { "Two answers needed" }
        val state = state()
        if (!state.created) throw VaultStateException("not_created", "No vault yet")
        // Turning the password on for the first time; later changes need the
        // old PIN / answers / Recovery Key (see below).
        if (state.hasPin && session == null) {
            throw VaultStateException("locked", "Unlock first")
        }
        state.setPinAndAnswers(pin, answers)
        state.passwordEnabled = true
    }

    /** {ok, waitMillis}; a right PIN unlocks the vault. */
    private fun verifyPin(pin: String): Map<String, Any> {
        val state = state()
        val wait = state.waitMillis()
        if (wait > 0) return mapOf("ok" to false, "waitMillis" to wait)
        val ok = state.checkPin(pin)
        if (ok) unlockFromState(state)
        return mapOf("ok" to ok, "waitMillis" to state.waitMillis())
    }

    private fun verifyAnswers(answers: List<String>): Map<String, Any> {
        val state = state()
        val wait = state.waitMillis()
        if (wait > 0) return mapOf("ok" to false, "waitMillis" to wait)
        val ok = state.checkAnswers(answers)
        return mapOf("ok" to ok, "waitMillis" to state.waitMillis())
    }

    /** Forgot PIN: the right answers allow a new PIN (and unlock). */
    private fun setPinWithAnswers(answers: List<String>, pin: String): Map<String, Any> {
        requirePin(pin)
        val checked = verifyAnswers(answers)
        if (checked["ok"] != true) return checked
        val state = state()
        state.setPin(pin)
        unlockFromState(state)
        return checked
    }

    /**
     * Forgot PIN AND answers: the Recovery Key opens vault.key in the
     * folder; if it gives this phone's DEK, a new PIN is set.
     */
    private fun setPinWithRecoveryKey(recoveryKey: String, pin: String): Map<String, Any> {
        requirePin(pin)
        val state = state()
        val wait = state.waitMillis()
        if (wait > 0) return mapOf("ok" to false, "waitMillis" to wait)
        val keyFile = folder.findKeyFile()
            ?: throw VaultStateException("no_key_file", "vault.key is missing")
        val fromFolder = try {
            VaultKeyFile.unlock(folder.read(keyFile), recoveryKey)
        } catch (error: VaultFormatException) {
            null
        }
        val mine = state.dek()
        val ok = fromFolder != null && mine != null && MessageDigest.isEqual(fromFolder, mine)
        VaultCrypto.wipe(fromFolder)
        VaultCrypto.wipe(mine)
        if (!ok) {
            // Counts as a wrong try (same waits as a wrong PIN).
            state.recordFailedTry()
            return mapOf("ok" to false, "waitMillis" to state.waitMillis())
        }
        state.setPin(pin)
        unlockFromState(state)
        return mapOf("ok" to true, "waitMillis" to 0L)
    }

    /** The settings switch; needs the vault unlocked (verified) first. */
    private fun setPasswordEnabled(enabled: Boolean) {
        val state = state()
        if (session == null) throw VaultStateException("locked", "Unlock first")
        if (enabled && !state.hasPin) throw VaultStateException("no_pin", "Set a PIN first")
        state.passwordEnabled = enabled
    }

    private fun requirePin(pin: String) {
        require(pin.length == 6 && pin.all { it in '0'..'9' }) { "PIN must be 6 digits" }
    }

    private fun replaceSession(dek: ByteArray) {
        val old = session
        session = dek
        VaultCrypto.wipe(old)
    }

    /**
     * FLAG_SECURE while vault / security screens are open: no screenshots,
     * no screen recording, and a blank card in Recent apps.
     */
    private fun setSecure(secure: Boolean) {
        if (secure) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    /**
     * The Recovery Key on the clipboard, marked sensitive (Android 13+ then
     * hides it in the clipboard preview and keyboard suggestions).
     */
    private fun copySensitive(text: String) {
        val clip = ClipData.newPlainText("Recovery Key", text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            clip.description.extras = PersistableBundle().apply {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            }
        }
        activity.getSystemService(ClipboardManager::class.java).setPrimaryClip(clip)
    }

    /**
     * Reset vault (PIN, answers and Recovery Key all lost): every vault file
     * this app made is deleted, the phone state erased, a fresh start.
     */
    private fun reset() {
        lock()
        folder.deleteAll()
        state().erase()
    }

    /**
     * Hide [items] ({id, video}): encrypt each into the vault folder
     * (progress "hideProgress" {done, total}), then ONE system request to
     * delete the originals. Answers {status: "hidden", hidden, failed} or
     * {status: "cancelled"} (nothing changed: the vault copies are removed).
     */
    private fun hide(call: MethodCall, result: MethodChannel.Result) {
        val dek = session?.copyOf()
        if (dek == null) {
            result.error("locked", "Unlock first", null)
            return
        }
        val sources = call.argument<List<Map<String, Any>>>("items").orEmpty().mapNotNull {
            val id = (it["id"] as? String)?.toLongOrNull() ?: return@mapNotNull null
            VaultHider.Source(id, it["video"] == true, it["favorite"] == true)
        }
        worker.execute {
            val hidden = try {
                hider.encryptAll(sources, dek) { done, total ->
                    main.post {
                        channel?.invokeMethod("hideProgress", mapOf("done" to done, "total" to total))
                    }
                }
            } finally {
                VaultCrypto.wipe(dek)
            }
            main.post { askDeleteOriginals(hidden, sources.size, result) }
        }
    }

    private fun askDeleteOriginals(
        hidden: List<VaultHider.Hidden>,
        total: Int,
        result: MethodChannel.Result,
    ) {
        if (hidden.isEmpty()) {
            result.success(mapOf("status" to "hidden", "hidden" to 0, "failed" to total))
            return
        }
        pendingHideResult?.success(mapOf("status" to "cancelled"))
        pendingHide = hidden
        pendingHideTotal = total
        pendingHideResult = result
        try {
            val request = MediaStore.createDeleteRequest(
                activity.contentResolver,
                hidden.map { it.original },
            )
            activity.startIntentSenderForResult(
                request.intentSender, REQUEST_DELETE, null, 0, 0, 0,
            )
        } catch (error: Exception) {
            finishHide(allowed = false)
        }
    }

    /** A system screen came back (delete request, folder picker). true = ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_TREE) {
            folderPicked(if (resultCode == Activity.RESULT_OK) data?.data else null)
            return true
        }
        if (requestCode != REQUEST_DELETE) return false
        finishHide(allowed = resultCode == Activity.RESULT_OK)
        return true
    }

    private fun finishHide(allowed: Boolean) {
        val hidden = pendingHide ?: return
        val result = pendingHideResult
        val total = pendingHideTotal
        pendingHide = null
        pendingHideResult = null
        if (allowed) {
            result?.success(
                mapOf(
                    "status" to "hidden",
                    "hidden" to hidden.size,
                    "failed" to total - hidden.size,
                ),
            )
        } else {
            // Nothing may change: remove the vault copies again.
            worker.execute {
                hider.rollback(hidden)
                main.post { result?.success(mapOf("status" to "cancelled")) }
            }
        }
    }

    /**
     * Unhide ([toTrash] false) or Delete with Recently deleted on (true):
     * each item decrypted back into the gallery ("restoreProgress"
     * {done, total}). {done, failed}.
     */
    private fun restore(ids: List<String>, toTrash: Boolean): Map<String, Any> =
        withSession { dek ->
            var done = 0
            // New gallery ids of items that had a heart (Dart gives it back).
            val favorites = mutableListOf<String>()
            ids.forEachIndexed { index, id ->
                val restored = try {
                    restorer.restore(id.toLong(), dek, toTrash)
                } catch (error: Exception) {
                    null
                }
                if (restored != null) {
                    done++
                    if (restored.favorite) favorites += restored.galleryId.toString()
                }
                main.post {
                    channel?.invokeMethod(
                        "restoreProgress",
                        mapOf("done" to index + 1, "total" to ids.size),
                    )
                }
            }
            mapOf("done" to done, "failed" to ids.size - done, "favorites" to favorites)
        }

    /** Delete with Recently deleted off: the vault files go for good. */
    private fun deleteForGood(ids: List<String>): Map<String, Int> {
        // Only an open vault may delete (same rule as the rest).
        withSession { }
        val done = ids.count { id ->
            try {
                restorer.deleteForGood(id.toLong())
            } catch (error: Exception) {
                false
            }
        }
        return mapOf("done" to done, "failed" to ids.size - done)
    }

    /**
     * Restore, step 1: the system folder picker, opened at
     * Documents/ProAlbums Vault. Answers {status: picked, items, hasKey} or
     * {status: cancelled}.
     */
    private fun pickVaultFolder(result: MethodChannel.Result) {
        pendingPick?.success(mapOf("status" to "cancelled"))
        pendingPick = result
        val start = DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            "primary:${VaultFolder.RELATIVE_PATH.trimEnd('/')}",
        )
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
            .putExtra(DocumentsContract.EXTRA_INITIAL_URI, start)
            .addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        try {
            activity.startActivityForResult(intent, REQUEST_TREE)
        } catch (error: Exception) {
            folderPicked(null)
        }
    }

    private fun folderPicked(tree: Uri?) {
        val result = pendingPick ?: return
        pendingPick = null
        if (tree == null) {
            result.success(mapOf("status" to "cancelled"))
            return
        }
        worker.execute {
            val found = try {
                importer.list(tree)
            } catch (error: Exception) {
                null
            }
            picked = found
            main.post {
                result.success(
                    mapOf(
                        "status" to "picked",
                        "items" to (found?.items?.size ?: 0),
                        "hasKey" to (found?.keys?.isNotEmpty() == true),
                    ),
                )
            }
        }
    }

    /**
     * Restore, step 2: the Recovery Key opens the old vault key, then each
     * old hidden file is copied into this vault ("importProgress"
     * {done, total}). {status: wrongKey} or {status: restored, restored,
     * failed}.
     */
    private fun importFromFolder(recoveryKey: String): Map<String, Any> {
        val found = picked ?: throw VaultStateException("no_folder", "Pick the folder first")
        val state = state()
        val wait = state.waitMillis()
        if (wait > 0) return mapOf("status" to "wait", "waitMillis" to wait)
        val (oldDek, keyDoc) = importer.unlockOld(found, recoveryKey) ?: run {
            state.recordFailedTry()
            return mapOf("status" to "wrongKey", "waitMillis" to state.waitMillis())
        }
        state.clearFailures()
        try {
            // The key file this restore makes (none when merging into a vault).
            var ownKey: Uri? = null
            val newDek = if (state.created) {
                // A vault already exists on this install: one vault, its key.
                session?.copyOf() ?: throw VaultStateException("locked", "Unlock first")
            } else {
                // First vault on this install: the old one comes back as it
                // was (same Recovery Key).
                ownKey = folder.create(VaultFolder.KEY_FILE, VaultKeyFile.create(oldDek, recoveryKey))
                state.setDek(oldDek)
                state.recoveryKeySaved = true
                replaceSession(oldDek.copyOf())
                oldDek.copyOf()
            }
            try {
                val ours = folder.itemNames()
                val items = found.items.filter { it.name !in ours }
                var restored = 0
                items.forEachIndexed { index, item ->
                    val ok = try {
                        importer.import(item, oldDek, newDek)
                    } catch (error: Exception) {
                        false
                    }
                    if (ok) restored++
                    main.post {
                        channel?.invokeMethod(
                            "importProgress",
                            mapOf("done" to index + 1, "total" to items.size),
                        )
                    }
                }
                // Everything copied: the old key file is not needed any more.
                if (restored == items.size) {
                    importer.delete(keyDoc.uri)
                    // Ours was named "vault.key (1)" while the old one was
                    // there: back to plain vault.key (else the next restore
                    // after a reinstall would not find it).
                    ownKey?.let {
                        try {
                            folder.rename(it, VaultFolder.KEY_FILE)
                        } catch (error: Exception) {
                            // Found anyway: any vault*.key name works.
                        }
                    }
                }
                picked = null
                return mapOf(
                    "status" to "restored",
                    "restored" to restored,
                    "failed" to items.size - restored,
                )
            } finally {
                VaultCrypto.wipe(newDek)
            }
        } finally {
            VaultCrypto.wipe(oldDek)
        }
    }

    /** A strong biometric (fingerprint...) is set up and usable. */
    private fun biometricAvailable(): Boolean =
        activity.getSystemService(BiometricManager::class.java)
            .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS

    /**
     * The system fingerprint sheet, alone (no app card behind it). Its button
     * is [usePassword] ("Use password"). Answers "ok", "usePassword" (that
     * button), "cancelled" (back / tap outside) or "error" (locked out,
     * sensor busy...: the PIN is the way then).
     */
    private fun authenticateBiometric(
        title: String,
        usePassword: String,
        result: MethodChannel.Result,
    ) {
        var answered = false
        fun answer(value: String) {
            if (answered) return
            answered = true
            result.success(value)
        }
        val prompt = BiometricPrompt.Builder(activity)
            .setTitle(title)
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .setNegativeButton(usePassword, activity.mainExecutor) { _, _ ->
                answer("usePassword")
            }
            .build()
        prompt.authenticate(
            CancellationSignal(),
            activity.mainExecutor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    authResult: BiometricPrompt.AuthenticationResult,
                ) = answer("ok")

                override fun onAuthenticationError(code: Int, message: CharSequence) {
                    answer(
                        when (code) {
                            BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED,
                            BiometricPrompt.BIOMETRIC_ERROR_CANCELED -> "cancelled"
                            else -> "error"
                        },
                    )
                }
                // A wrong finger: the sheet says so itself and stays open.
            },
        )
    }

    /** Wipes the DEK from memory (auto-lock, leaving the vault). */
    fun lock() {
        val old = session
        session = null
        VaultCrypto.wipe(old)
        // No hidden video can be played once locked.
        videos.stop()
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/vault"
        const val REQUEST_DELETE = 7203
        const val REQUEST_TREE = 7204
    }
}

/** A vault step that is not allowed right now ([code] goes to Dart). */
class VaultStateException(val code: String, message: String) : Exception(message)
