package com.aayush.proalbums.vault

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The vault's private state on THIS phone (app-private file, locked with a
 * Keystore key that never leaves the phone's secure hardware):
 *  - the DEK (so the vault opens with PIN / fingerprint, or with nothing
 *    when "Password for hidden photos" is off),
 *  - checks for the PIN and the two answers (salted PBKDF2, never the
 *    values themselves),
 *  - wrong-PIN count and wait.
 *
 * Gone on uninstall (with the Keystore key) — the vault folder's vault.key
 * + the Recovery Key bring the DEK back then.
 */
class VaultState private constructor(private val file: File, private val json: JSONObject) {

    val created: Boolean get() = json.has(DEK)
    val hasPin: Boolean get() = json.has(PIN_HASH)
    var passwordEnabled: Boolean
        get() = json.optBoolean(PASSWORD_ENABLED, false)
        set(value) {
            json.put(PASSWORD_ENABLED, value)
            save()
        }
    var recoveryKeySaved: Boolean
        get() = json.optBoolean(RECOVERY_SAVED, false)
        set(value) {
            json.put(RECOVERY_SAVED, value)
            save()
        }

    /** The DEK (a copy; the caller wipes it). */
    fun dek(): ByteArray? = json.optString(DEK, "").takeIf { it.isNotEmpty() }?.let(::decode)

    fun setDek(dek: ByteArray) {
        json.put(DEK, encode(dek))
        save()
    }

    fun setPinAndAnswers(pin: String, answers: List<String>) {
        json.put(PIN_SALT, encode(VaultCrypto.randomBytes(SALT_BYTES)))
        json.put(PIN_HASH, encode(hash(pin, PIN_SALT)))
        json.put(ANSWER_SALT, encode(VaultCrypto.randomBytes(SALT_BYTES)))
        json.put(ANSWER_HASHES, JSONArray(answers.map { encode(hash(it, ANSWER_SALT)) }))
        json.put(FAILED, 0)
        json.put(WAIT_UNTIL, 0L)
        save()
    }

    fun setPin(pin: String) {
        json.put(PIN_SALT, encode(VaultCrypto.randomBytes(SALT_BYTES)))
        json.put(PIN_HASH, encode(hash(pin, PIN_SALT)))
        clearFailures()
    }

    /** Milliseconds to wait before another try is allowed (0 = now). */
    fun waitMillis(now: Long = System.currentTimeMillis()): Long =
        (json.optLong(WAIT_UNTIL, 0L) - now).coerceAtLeast(0L)

    fun checkPin(pin: String): Boolean = check(pin, PIN_SALT, PIN_HASH)

    fun checkAnswers(answers: List<String>): Boolean {
        val stored = json.optJSONArray(ANSWER_HASHES) ?: return false
        if (stored.length() != answers.size) return false
        // Every answer is checked (no early stop), both must match.
        var allMatch = true
        for (index in answers.indices) {
            val expected = decode(stored.getString(index))
            if (!MessageDigest.isEqual(expected, hash(answers[index], ANSWER_SALT))) {
                allMatch = false
            }
        }
        recordTry(allMatch)
        return allMatch
    }

    fun clearFailures() {
        json.put(FAILED, 0)
        json.put(WAIT_UNTIL, 0L)
        save()
    }

    /** Forget everything (Reset vault). */
    fun erase() {
        json.keys().asSequence().toList().forEach(json::remove)
        file.delete()
    }

    private fun check(secret: String, saltKey: String, hashKey: String): Boolean {
        val expected = json.optString(hashKey, "").takeIf { it.isNotEmpty() } ?: return false
        val ok = MessageDigest.isEqual(decode(expected), hash(secret, saltKey))
        recordTry(ok)
        return ok
    }

    /** A wrong Recovery Key counts like a wrong PIN. */
    fun recordFailedTry() = recordTry(false)

    /** 5 wrong tries are free; then 30 s, 60 s, 120 s ... up to 1 hour. */
    private fun recordTry(ok: Boolean) {
        if (ok) {
            clearFailures()
            return
        }
        val failed = json.optInt(FAILED, 0) + 1
        json.put(FAILED, failed)
        if (failed >= FREE_TRIES) {
            val wait = (WAIT_START_MS shl (failed - FREE_TRIES).coerceAtMost(7))
                .coerceAtMost(WAIT_MAX_MS)
            json.put(WAIT_UNTIL, System.currentTimeMillis() + wait)
        }
        save()
    }

    private fun hash(secret: String, saltKey: String): ByteArray =
        VaultCrypto.deriveKey(secret.toCharArray(), decode(json.getString(saltKey)), HASH_ITERATIONS)

    private fun save() {
        file.parentFile?.mkdirs()
        val plain = json.toString().toByteArray()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, keystoreKey())
        val sealed = cipher.iv + cipher.doFinal(plain)
        VaultCrypto.wipe(plain)
        val temp = File(file.parentFile, file.name + ".tmp")
        temp.writeBytes(sealed)
        if (!temp.renameTo(file)) {
            file.delete()
            temp.renameTo(file)
        }
    }

    companion object {
        private const val ALIAS = "proalbums_vault_state"
        private const val SALT_BYTES = 16
        private const val HASH_ITERATIONS = 120_000
        private const val FREE_TRIES = 5
        private const val WAIT_START_MS = 30_000L
        private const val WAIT_MAX_MS = 60 * 60_000L

        private const val DEK = "dek"
        private const val PIN_SALT = "pinSalt"
        private const val PIN_HASH = "pinHash"
        private const val ANSWER_SALT = "answerSalt"
        private const val ANSWER_HASHES = "answerHashes"
        private const val PASSWORD_ENABLED = "passwordEnabled"
        private const val RECOVERY_SAVED = "recoveryKeySaved"
        private const val FAILED = "failed"
        private const val WAIT_UNTIL = "waitUntil"

        /** The state in [file]; empty when there is none (or it cannot be read). */
        fun load(file: File): VaultState {
            if (!file.exists()) return VaultState(file, JSONObject())
            return try {
                val sealed = file.readBytes()
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(
                    Cipher.DECRYPT_MODE,
                    keystoreKey(),
                    GCMParameterSpec(128, sealed.copyOfRange(0, 12)),
                )
                val plain = cipher.doFinal(sealed, 12, sealed.size - 12)
                VaultState(file, JSONObject(String(plain))).also { VaultCrypto.wipe(plain) }
            } catch (error: Exception) {
                // The Keystore key is gone (e.g. app data restored on another
                // phone): this phone's state is unusable; the Recovery Key
                // brings the vault back.
                VaultState(file, JSONObject())
            }
        }

        /** The phone's own AES key for the state file (made once). */
        private fun keystoreKey(): SecretKey {
            val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
            fun generate(strongBox: Boolean): SecretKey {
                val spec = KeyGenParameterSpec.Builder(
                    ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .setIsStrongBoxBacked(strongBox)
                    .build()
                return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
                    .apply { init(spec) }
                    .generateKey()
            }
            // StrongBox (a separate security chip) when the phone has one;
            // phones without it throw StrongBoxUnavailableException, some
            // OEMs another error, so any failure falls back to the normal
            // (still hardware-backed) Keystore.
            return try {
                generate(strongBox = true)
            } catch (error: StrongBoxUnavailableException) {
                generate(strongBox = false)
            } catch (error: java.security.ProviderException) {
                generate(strongBox = false)
            }
        }

        private fun encode(bytes: ByteArray) = Base64.encodeToString(bytes, Base64.NO_WRAP)

        private fun decode(text: String) = Base64.decode(text, Base64.NO_WRAP)
    }
}
