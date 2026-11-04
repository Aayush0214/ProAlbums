package com.aayush.proalbums.vault

import java.io.EOFException
import java.io.InputStream
import java.io.OutputStream
import java.nio.ByteBuffer
import java.security.GeneralSecurityException
import java.security.SecureRandom
import java.util.Arrays
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * The vault's encryption, in plain Kotlin (no Android), so it can be tested
 * on the computer (src/test). Android only adds where the bytes live
 * (MediaStore, Keystore) — see VaultChannel.
 *
 * Keys:
 *  - DEK (data key, 32 random bytes): locks every hidden file. Never stored
 *    in the clear. Two locked copies: one with the phone's Keystore key
 *    (daily use, app-private), one with the Recovery Key (in the vault
 *    folder, for after a reinstall).
 *  - File key (32 random bytes per hidden file), locked with the DEK inside
 *    that file.
 *
 * All locking is AES-256-GCM: secret AND tamper-proof (a changed, swapped,
 * cut or added byte makes reading fail instead of giving wrong data).
 */
object VaultCrypto {
    const val KEY_BYTES = 32
    const val NONCE_BYTES = 12
    const val TAG_BYTES = 16

    private const val TAG_BITS = TAG_BYTES * 8
    private val random = SecureRandom()

    fun randomBytes(count: Int): ByteArray = ByteArray(count).also(random::nextBytes)

    fun newKey(): ByteArray = randomBytes(KEY_BYTES)

    /** nonce || ciphertext+tag, with a fresh random nonce. */
    fun seal(key: ByteArray, plain: ByteArray, aad: ByteArray): ByteArray {
        val nonce = randomBytes(NONCE_BYTES)
        return nonce + gcm(Cipher.ENCRYPT_MODE, key, nonce, aad, plain)
    }

    /** The plain bytes of [seal]'s output; throws if anything was changed. */
    fun open(key: ByteArray, sealed: ByteArray, aad: ByteArray): ByteArray {
        if (sealed.size < NONCE_BYTES + TAG_BYTES) throw VaultFormatException("Too short")
        val nonce = sealed.copyOfRange(0, NONCE_BYTES)
        return gcm(
            Cipher.DECRYPT_MODE,
            key,
            nonce,
            aad,
            sealed.copyOfRange(NONCE_BYTES, sealed.size),
        )
    }

    internal fun gcm(
        mode: Int,
        key: ByteArray,
        nonce: ByteArray,
        aad: ByteArray,
        data: ByteArray,
        length: Int = data.size,
    ): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(mode, SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_BITS, nonce))
        cipher.updateAAD(aad)
        return try {
            cipher.doFinal(data, 0, length)
        } catch (error: GeneralSecurityException) {
            throw VaultFormatException("Wrong key or damaged data", error)
        }
    }

    /** A slow, salted key from a secret (PBKDF2-HMAC-SHA256). */
    fun deriveKey(secret: CharArray, salt: ByteArray, iterations: Int): ByteArray {
        val spec = PBEKeySpec(secret, salt, iterations, KEY_BYTES * 8)
        try {
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                .generateSecret(spec).encoded
        } finally {
            spec.clearPassword()
        }
    }

    fun wipe(bytes: ByteArray?) {
        if (bytes != null) Arrays.fill(bytes, 0)
    }
}

/** A vault file or key that is damaged, changed, or locked with another key. */
class VaultFormatException(message: String, cause: Throwable? = null) :
    Exception(message, cause)

/**
 * The Recovery Key: 24 characters (Crockford base 32, no I/L/O/U, so it is
 * easy to write down and read back), about 120 bits — far too many to ever
 * guess, so a copied vault folder stays locked. Shown in groups of 4:
 * "K7QM-2XPA-9RTD-...".
 */
object RecoveryKey {
    const val LENGTH = 24
    private const val ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    private val random = SecureRandom()

    fun generate(): String {
        val chars = CharArray(LENGTH) { ALPHABET[random.nextInt(ALPHABET.length)] }
        return chars.toList().chunked(4).joinToString("-") { it.joinToString("") }
    }

    /**
     * What the person typed, made exact: spaces and dashes dropped, small
     * letters made big, look-alikes fixed (O → 0, I/L → 1). null when it
     * cannot be a Recovery Key.
     */
    fun normalize(typed: String): String? {
        val cleaned = buildString {
            for (char in typed.uppercase()) {
                when (char) {
                    ' ', '-', '\n', '\t' -> Unit
                    'O' -> append('0')
                    'I', 'L' -> append('1')
                    else -> append(char)
                }
            }
        }
        if (cleaned.length != LENGTH || cleaned.any { it !in ALPHABET }) return null
        return cleaned
    }
}

/**
 * vault.key, in the vault folder: the DEK locked with the Recovery Key.
 * The ONLY key material that leaves the phone's private storage.
 *
 *   "PAVK" | version (1) | iterations (4) | salt (16) | seal(KEK, DEK)
 */
object VaultKeyFile {
    private val MAGIC = "PAVK".toByteArray()
    private const val VERSION: Byte = 1
    private const val SALT_BYTES = 16
    const val ITERATIONS = 210_000
    private val AAD = "PAVK/1/dek".toByteArray()

    fun create(dek: ByteArray, recoveryKey: String): ByteArray {
        val normalized = RecoveryKey.normalize(recoveryKey)
            ?: throw IllegalArgumentException("Not a Recovery Key")
        val salt = VaultCrypto.randomBytes(SALT_BYTES)
        val kek = VaultCrypto.deriveKey(normalized.toCharArray(), salt, ITERATIONS)
        try {
            val sealed = VaultCrypto.seal(kek, dek, AAD)
            return ByteBuffer.allocate(MAGIC.size + 1 + 4 + SALT_BYTES + sealed.size)
                .put(MAGIC).put(VERSION).putInt(ITERATIONS).put(salt).put(sealed)
                .array()
        } finally {
            VaultCrypto.wipe(kek)
        }
    }

    /** The DEK; throws VaultFormatException for a wrong key or a bad file. */
    fun unlock(file: ByteArray, recoveryKey: String): ByteArray {
        val normalized = RecoveryKey.normalize(recoveryKey)
            ?: throw VaultFormatException("Not a Recovery Key")
        val buffer = ByteBuffer.wrap(file)
        if (file.size < MAGIC.size + 1 + 4 + SALT_BYTES) throw VaultFormatException("Too short")
        val magic = ByteArray(MAGIC.size).also(buffer::get)
        if (!magic.contentEquals(MAGIC)) throw VaultFormatException("Not a vault key")
        if (buffer.get() != VERSION) throw VaultFormatException("Unknown version")
        val iterations = buffer.int
        if (iterations !in 10_000..10_000_000) throw VaultFormatException("Bad iterations")
        val salt = ByteArray(SALT_BYTES).also(buffer::get)
        val sealed = ByteArray(buffer.remaining()).also(buffer::get)
        val kek = VaultCrypto.deriveKey(normalized.toCharArray(), salt, iterations)
        try {
            return VaultCrypto.open(kek, sealed, AAD)
        } finally {
            VaultCrypto.wipe(kek)
        }
    }
}

/**
 * One hidden picture / video ("<random>.pav"):
 *
 *   "PAV1" | version (1)
 *   seal(DEK, file key)                          — 60 bytes
 *   length (4) | seal(file key, header)          — name, folder, dates... (JSON)
 *   length (4) | seal(file key, thumbnail)       — small JPEG for the grid
 *   nonce prefix (8)
 *   chunks: AES-GCM(file key, prefix || index) of 1 MiB each (last may be
 *           shorter); extra data = index + "is last", so chunks cannot be
 *           reordered, dropped or cut off.
 *
 * Chunks let a video be read from any point (seeking) without decrypting
 * the whole file, and never need the whole file in memory.
 */
object VaultItemFormat {
    val MAGIC = "PAV1".toByteArray()
    const val VERSION: Byte = 1
    const val CHUNK_BYTES = 1 shl 20
    const val CHUNK_CIPHER_BYTES = CHUNK_BYTES + VaultCrypto.TAG_BYTES
    const val PREFIX_BYTES = 8

    internal val KEY_AAD = "PAV1/key".toByteArray()
    internal val HEADER_AAD = "PAV1/header".toByteArray()
    internal val THUMB_AAD = "PAV1/thumb".toByteArray()
    private val CHUNK_AAD = "PAV1/chunk".toByteArray()

    internal fun chunkNonce(prefix: ByteArray, index: Int): ByteArray =
        ByteBuffer.allocate(VaultCrypto.NONCE_BYTES).put(prefix).putInt(index).array()

    internal fun chunkAad(index: Int, last: Boolean): ByteArray =
        ByteBuffer.allocate(CHUNK_AAD.size + 5).put(CHUNK_AAD).putInt(index)
            .put(if (last) 1 else 0).array()

    /**
     * Encrypts [content] (read to its end) into [out]. Returns the number of
     * plain bytes. [header] and [thumbnail] go in sealed too.
     */
    fun write(
        out: OutputStream,
        dek: ByteArray,
        header: ByteArray,
        thumbnail: ByteArray,
        content: InputStream,
        onChunk: (plainBytesDone: Long) -> Unit = {},
    ): Long {
        val fileKey = VaultCrypto.newKey()
        try {
            out.write(MAGIC)
            out.write(VERSION.toInt())
            out.write(VaultCrypto.seal(dek, fileKey, KEY_AAD))
            writeSealed(out, VaultCrypto.seal(fileKey, header, HEADER_AAD))
            writeSealed(out, VaultCrypto.seal(fileKey, thumbnail, THUMB_AAD))
            val prefix = VaultCrypto.randomBytes(PREFIX_BYTES)
            out.write(prefix)

            // Read one chunk ahead, to know which one is the last.
            var current = ByteArray(CHUNK_BYTES)
            var next = ByteArray(CHUNK_BYTES)
            var currentLength = readUpTo(content, current)
            var index = 0
            var total = 0L
            while (true) {
                val nextLength =
                    if (currentLength == CHUNK_BYTES) readUpTo(content, next) else 0
                val last = nextLength == 0
                out.write(
                    VaultCrypto.gcm(
                        javax.crypto.Cipher.ENCRYPT_MODE,
                        fileKey,
                        chunkNonce(prefix, index),
                        chunkAad(index, last),
                        current,
                        currentLength,
                    ),
                )
                total += currentLength
                onChunk(total)
                if (last) break
                index++
                if (index < 0) throw VaultFormatException("File too big")
                val swap = current
                current = next
                next = swap
                currentLength = nextLength
            }
            Arrays.fill(current, 0)
            Arrays.fill(next, 0)
            return total
        } finally {
            VaultCrypto.wipe(fileKey)
        }
    }

    private fun writeSealed(out: OutputStream, sealed: ByteArray) {
        out.write(ByteBuffer.allocate(4).putInt(sealed.size).array())
        out.write(sealed)
    }

    /** Fills [buffer] as far as the stream allows; the count read. */
    private fun readUpTo(input: InputStream, buffer: ByteArray): Int {
        var filled = 0
        while (filled < buffer.size) {
            val read = input.read(buffer, filled, buffer.size - filled)
            if (read < 0) break
            filled += read
        }
        return filled
    }
}

/** Bytes at any position: a file channel on the phone, an array in tests. */
interface VaultSource {
    val size: Long

    /** Exactly [length] bytes from [position] into [into] (throws at the end). */
    fun readFully(position: Long, into: ByteArray, length: Int = into.size)
}

class ByteArrayVaultSource(private val bytes: ByteArray) : VaultSource {
    override val size: Long get() = bytes.size.toLong()

    override fun readFully(position: Long, into: ByteArray, length: Int) {
        if (position < 0 || position + length > bytes.size) throw EOFException()
        System.arraycopy(bytes, position.toInt(), into, 0, length)
    }
}

/**
 * Reads one hidden file: header, thumbnail, and any part of the content.
 * Every byte returned has been checked (GCM); a damaged file throws
 * VaultFormatException. Call [close] to wipe the file key.
 */
class VaultItemReader(private val source: VaultSource, dek: ByteArray) : AutoCloseable {
    private val fileKey: ByteArray
    private val headerSealed: ByteArray
    private val thumbPosition: Long
    private val thumbLength: Int
    private val prefix = ByteArray(VaultItemFormat.PREFIX_BYTES)
    private val contentStart: Long

    /** Chunks in the file (at least 1, even for an empty file). */
    val chunkCount: Int

    /** Size of the original picture / video in bytes. */
    val plainSize: Long

    init {
        var position = 0L
        fun read(count: Int): ByteArray {
            if (count < 0 || position + count > source.size) {
                throw VaultFormatException("Cut off")
            }
            return ByteArray(count).also {
                source.readFully(position, it)
                position += count
            }
        }

        if (!read(4).contentEquals(VaultItemFormat.MAGIC)) {
            throw VaultFormatException("Not a vault file")
        }
        if (read(1)[0] != VaultItemFormat.VERSION) throw VaultFormatException("Unknown version")
        val wrappedKey = read(VaultCrypto.NONCE_BYTES + VaultCrypto.KEY_BYTES + VaultCrypto.TAG_BYTES)
        fileKey = VaultCrypto.open(dek, wrappedKey, VaultItemFormat.KEY_AAD)
        headerSealed = read(ByteBuffer.wrap(read(4)).int)
        thumbLength = ByteBuffer.wrap(read(4)).int
        if (thumbLength < 0) throw VaultFormatException("Bad thumbnail")
        thumbPosition = position
        position += thumbLength
        read(VaultItemFormat.PREFIX_BYTES).copyInto(prefix)
        contentStart = position

        val cipherBytes = source.size - contentStart
        if (cipherBytes < VaultCrypto.TAG_BYTES) throw VaultFormatException("No content")
        val chunks = (cipherBytes + VaultItemFormat.CHUNK_CIPHER_BYTES - 1) /
            VaultItemFormat.CHUNK_CIPHER_BYTES
        val lastCipher = cipherBytes - (chunks - 1) * VaultItemFormat.CHUNK_CIPHER_BYTES
        if (lastCipher < VaultCrypto.TAG_BYTES || chunks > Int.MAX_VALUE) {
            throw VaultFormatException("Bad content size")
        }
        chunkCount = chunks.toInt()
        plainSize = (chunks - 1) * VaultItemFormat.CHUNK_BYTES + lastCipher - VaultCrypto.TAG_BYTES
    }

    fun header(): ByteArray = VaultCrypto.open(fileKey, headerSealed, VaultItemFormat.HEADER_AAD)

    fun thumbnail(): ByteArray {
        val sealed = ByteArray(thumbLength)
        source.readFully(thumbPosition, sealed)
        return VaultCrypto.open(fileKey, sealed, VaultItemFormat.THUMB_AAD)
    }

    /** The plain bytes of chunk [index] (checked). */
    fun chunk(index: Int): ByteArray {
        if (index !in 0 until chunkCount) throw IndexOutOfBoundsException("Chunk $index")
        val last = index == chunkCount - 1
        val position = contentStart + index.toLong() * VaultItemFormat.CHUNK_CIPHER_BYTES
        val length = if (last) {
            (source.size - position).toInt()
        } else {
            VaultItemFormat.CHUNK_CIPHER_BYTES
        }
        val cipher = ByteArray(length)
        source.readFully(position, cipher)
        return VaultCrypto.gcm(
            Cipher.DECRYPT_MODE,
            fileKey,
            VaultItemFormat.chunkNonce(prefix, index),
            VaultItemFormat.chunkAad(index, last),
            cipher,
        )
    }

    /** [length] plain bytes from [position] (clamped to the end). */
    fun read(position: Long, length: Int): ByteArray {
        if (position < 0 || length < 0) throw IllegalArgumentException("Bad range")
        val end = minOf(plainSize, position + length)
        if (position >= end) return ByteArray(0)
        val out = ByteArray((end - position).toInt())
        var written = 0
        var at = position
        while (at < end) {
            val index = (at / VaultItemFormat.CHUNK_BYTES).toInt()
            val plain = chunk(index)
            val from = (at - index.toLong() * VaultItemFormat.CHUNK_BYTES).toInt()
            val count = minOf(plain.size - from, (end - at).toInt())
            System.arraycopy(plain, from, out, written, count)
            Arrays.fill(plain, 0)
            written += count
            at += count
        }
        return out
    }

    /** The whole original, chunk by chunk, into [out]. */
    fun copyTo(out: OutputStream, onChunk: (plainBytesDone: Long) -> Unit = {}) {
        var done = 0L
        for (index in 0 until chunkCount) {
            val plain = chunk(index)
            out.write(plain)
            done += plain.size
            Arrays.fill(plain, 0)
            onChunk(done)
        }
    }

    override fun close() {
        VaultCrypto.wipe(fileKey)
    }
}

/** File names in the vault folder. */
object VaultNames {
    private val renamedKey = Regex("""^vault( \(\d+\))?\.key( \(\d+\))?$""")

    /**
     * A vault key file: "vault.key", or one Android renamed because the name
     * was taken — "vault.key (1)" (it adds the number at the END for a file
     * type it does not know) or "vault (1).key".
     */
    fun isKeyFile(name: String): Boolean = renamedKey.matches(name)
}
