package com.aayush.proalbums.vault

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.FileInputStream
import java.util.UUID

/**
 * Restore after a reinstall (or a vault folder copied from another phone).
 *
 * After a reinstall Android no longer counts the vault files as ours, so the
 * person picks the folder once (system folder picker). Each old hidden file
 * is then COPIED into a new file of ours — still encrypted, never decrypted
 * to disk — and the old one removed:
 *  - no vault on this install yet: the old vault key (opened with the
 *    Recovery Key) becomes this vault's key; the Recovery Key stays the same;
 *  - a vault already made on this install: each file's key is re-locked with
 *    the current vault key (the two vaults become one).
 */
class VaultImporter(
    private val resolver: ContentResolver,
    private val folder: VaultFolder,
) {
    /** A file found in the picked folder. */
    class Document(val uri: Uri, val name: String)

    /** What the picked folder holds: key files and hidden items. */
    class Picked(val keys: List<Document>, val items: List<Document>)

    /** The picked folder's files (one level, no sub-folders). */
    fun list(tree: Uri): Picked {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        val keys = mutableListOf<Document>()
        val items = mutableListOf<Document>()
        resolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.getString(1) ?: continue
                val uri = DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0))
                when {
                    name.endsWith(".pav") -> items += Document(uri, name)
                    VaultNames.isKeyFile(name) -> keys += Document(uri, name)
                }
            }
        }
        // "vault.key" first (the original), then renamed copies.
        keys.sortBy { if (it.name == VaultFolder.KEY_FILE) 0 else 1 }
        return Picked(keys, items)
    }

    /** The old vault key from the first key file the Recovery Key opens; null = none. */
    fun unlockOld(picked: Picked, recoveryKey: String): Pair<ByteArray, Document>? {
        for (key in picked.keys) {
            val bytes = resolver.openInputStream(key.uri)?.use { it.readBytes() } ?: continue
            try {
                return VaultKeyFile.unlock(bytes, recoveryKey) to key
            } catch (error: VaultFormatException) {
                // Another vault's key, or a wrong Recovery Key: try the next.
            }
        }
        return null
    }

    /**
     * Copies [item] (locked with [oldDek]) into a new vault file of ours
     * locked with [newDek], then removes the old one. false = skipped (not
     * this vault's, already ours, or failed).
     */
    fun import(item: Document, oldDek: ByteArray, newDek: ByteArray): Boolean {
        val input = resolver.openInputStream(item.uri) ?: return false
        val target = input.use { stream ->
            val data = DataInputStream(stream)
            val magic = ByteArray(VaultItemFormat.MAGIC.size).also(data::readFully)
            if (!magic.contentEquals(VaultItemFormat.MAGIC)) return false
            val version = data.readByte()
            val wrapped = ByteArray(VaultCrypto.NONCE_BYTES + VaultCrypto.KEY_BYTES + VaultCrypto.TAG_BYTES)
            data.readFully(wrapped)
            val fileKey = try {
                VaultCrypto.open(oldDek, wrapped, VaultItemFormat.KEY_AAD)
            } catch (error: VaultFormatException) {
                return false
            }
            val rewrapped = try {
                if (oldDek.contentEquals(newDek)) wrapped else VaultCrypto.seal(newDek, fileKey, VaultItemFormat.KEY_AAD)
            } finally {
                VaultCrypto.wipe(fileKey)
            }
            val file = folder.insertPending("${UUID.randomUUID().toString().replace("-", "")}.pav")
            try {
                val out = resolver.openOutputStream(file, "w") ?: throw IllegalStateException("No output")
                BufferedOutputStream(out, 1 shl 16).use {
                    it.write(magic)
                    it.write(version.toInt())
                    it.write(rewrapped)
                    data.copyTo(it, 1 shl 16)
                }
                check(file, newDek)
                folder.publish(file)
                file
            } catch (error: Exception) {
                folder.delete(file)
                return false
            }
        }
        // The copy is complete and opens: the old file can go.
        delete(item.uri)
        return target != null
    }

    /** The copy opens with the vault key (header readable). */
    private fun check(file: Uri, dek: ByteArray) {
        resolver.openFileDescriptor(file, "r")!!.use { descriptor ->
            FileInputStream(descriptor.fileDescriptor).channel.use { channel ->
                VaultItemReader(FileChannelVaultSource(channel), dek).use { it.header() }
            }
        }
    }

    fun delete(uri: Uri) {
        try {
            DocumentsContract.deleteDocument(resolver, uri)
        } catch (error: Exception) {
            // Without write access the old copy stays; nothing breaks.
        }
    }
}
