package com.aayush.proalbums.vault

import android.app.Activity
import android.os.Handler
import android.os.Looper
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

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
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
            else -> result.notImplemented()
        }
    }

    /** Runs [work] on the worker; its value (or error) goes back to Dart. */
    private fun run(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work()
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
        val keyFile = folder.find(VaultFolder.KEY_FILE)
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

    /** Wipes the DEK from memory (auto-lock, leaving the vault). */
    fun lock() {
        val old = session
        session = null
        VaultCrypto.wipe(old)
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/vault"
    }
}

/** A vault step that is not allowed right now ([code] goes to Dart). */
class VaultStateException(val code: String, message: String) : Exception(message)
