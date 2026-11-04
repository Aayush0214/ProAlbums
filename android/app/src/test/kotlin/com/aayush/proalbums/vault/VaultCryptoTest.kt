package com.aayush.proalbums.vault

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlin.random.Random

class VaultCryptoTest {
    private val chunk = VaultItemFormat.CHUNK_BYTES

    private fun encrypt(
        content: ByteArray,
        dek: ByteArray,
        header: ByteArray = "{\"name\":\"a.jpg\"}".toByteArray(),
        thumb: ByteArray = byteArrayOf(1, 2, 3),
    ): ByteArray {
        val out = ByteArrayOutputStream()
        val written = VaultItemFormat.write(out, dek, header, thumb, ByteArrayInputStream(content))
        assertEquals(content.size.toLong(), written)
        return out.toByteArray()
    }

    @Test
    fun `round trip for every size around chunk edges`() {
        val dek = VaultCrypto.newKey()
        for (size in listOf(0, 1, chunk - 1, chunk, chunk + 1, chunk * 2 + chunk / 2)) {
            val content = Random(size).nextBytes(size)
            val file = encrypt(content, dek)
            VaultItemReader(ByteArrayVaultSource(file), dek).use { reader ->
                assertEquals(size.toLong(), reader.plainSize)
                val out = ByteArrayOutputStream()
                reader.copyTo(out)
                assertArrayEquals("size $size", content, out.toByteArray())
                assertArrayEquals("{\"name\":\"a.jpg\"}".toByteArray(), reader.header())
                assertArrayEquals(byteArrayOf(1, 2, 3), reader.thumbnail())
            }
        }
    }

    @Test
    fun `any range can be read without the rest (video seeking)`() {
        val dek = VaultCrypto.newKey()
        val content = Random(7).nextBytes(chunk * 3 + 123)
        val file = encrypt(content, dek)
        VaultItemReader(ByteArrayVaultSource(file), dek).use { reader ->
            for ((start, length) in listOf(
                0L to 10,
                (chunk - 5).toLong() to 10,
                (chunk * 2).toLong() to chunk + 50,
                (content.size - 3).toLong() to 100,
            )) {
                val end = minOf(content.size.toLong(), start + length).toInt()
                assertArrayEquals(
                    content.copyOfRange(start.toInt(), end),
                    reader.read(start, length),
                )
            }
            assertEquals(0, reader.read(content.size.toLong(), 10).size)
        }
    }

    @Test
    fun `the plain content is not in the file`() {
        val dek = VaultCrypto.newKey()
        val content = ByteArray(5000) { 0x41 }
        val file = encrypt(content, dek)
        val marker = ByteArray(64) { 0x41 }
        val text = file.toList().windowed(64).any { it.toByteArray().contentEquals(marker) }
        assertTrue("plain bytes leaked", !text)
    }

    @Test
    fun `wrong key, changed byte, cut file or swapped chunks all fail`() {
        val dek = VaultCrypto.newKey()
        val content = Random(3).nextBytes(chunk * 2 + 10)
        val file = encrypt(content, dek)

        assertThrows(VaultFormatException::class.java) {
            VaultItemReader(ByteArrayVaultSource(file), VaultCrypto.newKey())
        }

        val changed = file.copyOf().also { it[it.size - 5] = (it[it.size - 5] + 1).toByte() }
        VaultItemReader(ByteArrayVaultSource(changed), dek).use { reader ->
            assertThrows(VaultFormatException::class.java) { reader.chunk(reader.chunkCount - 1) }
        }

        // Cut off the last chunk: the one before was not written as "last".
        val reader = VaultItemReader(ByteArrayVaultSource(file), dek)
        val lastStart = file.size - (reader.plainSize - 2L * chunk + VaultCrypto.TAG_BYTES).toInt()
        reader.close()
        val cut = file.copyOfRange(0, lastStart)
        VaultItemReader(ByteArrayVaultSource(cut), dek).use { short ->
            assertThrows(VaultFormatException::class.java) { short.chunk(short.chunkCount - 1) }
        }

        // Swap the first two chunks.
        val start = lastStart - 2 * VaultItemFormat.CHUNK_CIPHER_BYTES
        val swapped = file.copyOf()
        val first = file.copyOfRange(start, start + VaultItemFormat.CHUNK_CIPHER_BYTES)
        val second = file.copyOfRange(
            start + VaultItemFormat.CHUNK_CIPHER_BYTES,
            start + 2 * VaultItemFormat.CHUNK_CIPHER_BYTES,
        )
        second.copyInto(swapped, start)
        first.copyInto(swapped, start + VaultItemFormat.CHUNK_CIPHER_BYTES)
        VaultItemReader(ByteArrayVaultSource(swapped), dek).use { mixed ->
            assertThrows(VaultFormatException::class.java) { mixed.chunk(0) }
        }
    }

    @Test
    fun `recovery key looks right and is typed back forgivingly`() {
        val key = RecoveryKey.generate()
        assertEquals(6, key.split("-").size)
        assertTrue(key.split("-").all { it.length == 4 })
        val normalized = RecoveryKey.normalize(key)
        assertNotNull(normalized)
        assertEquals(RecoveryKey.LENGTH, normalized!!.length)
        // Small letters, spaces, O instead of 0, l instead of 1.
        val typed = key.lowercase().replace("-", " ").replace('0', 'o').replace('1', 'l')
        assertEquals(normalized, RecoveryKey.normalize(typed))
        assertNull(RecoveryKey.normalize("too-short"))
        assertNull(RecoveryKey.normalize("U".repeat(24)))
        // Two keys are never the same.
        assertTrue(RecoveryKey.generate() != RecoveryKey.generate())
    }

    @Test
    fun `vault key file opens only with its recovery key`() {
        val dek = VaultCrypto.newKey()
        val key = RecoveryKey.generate()
        val file = VaultKeyFile.create(dek, key)
        assertArrayEquals(dek, VaultKeyFile.unlock(file, key.lowercase()))
        assertThrows(VaultFormatException::class.java) {
            VaultKeyFile.unlock(file, RecoveryKey.generate())
        }
        val changed = file.copyOf().also { it[it.size - 1] = (it[it.size - 1] + 1).toByte() }
        assertThrows(VaultFormatException::class.java) { VaultKeyFile.unlock(changed, key) }
    }

    @Test
    fun `key files are found also when Android renamed them`() {
        for (name in listOf("vault.key", "vault.key (1)", "vault.key (12)", "vault (1).key")) {
            assertTrue(name, VaultNames.isKeyFile(name))
        }
        for (name in listOf("vault.pav", "myvault.key", "vault.keys", "vault.key (x)", "a.key")) {
            assertTrue(name, !VaultNames.isKeyFile(name))
        }
    }
}
