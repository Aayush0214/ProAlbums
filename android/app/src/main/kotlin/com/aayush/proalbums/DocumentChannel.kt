package com.aayush.proalbums

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Documents made by the app (Convert PDF):
 *  - savePdf: copies a finished PDF into shared storage (Documents/ProAlbums)
 *    through MediaStore. No permission needed: an app may add its own files
 *    to Documents/.
 *  - openFolder: a file manager at that folder.
 *  - openPdf: a PDF viewer with one saved PDF.
 */
class DocumentChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "savePdf" -> savePdf(call, result)
            "openFolder" -> openFolder(call, result)
            "openPdf" -> openPdf(call, result)
            else -> result.notImplemented()
        }
    }

    private fun savePdf(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val name = call.argument<String>("name")
        val folder = call.argument<String>("folder")
        if (path == null || name == null || folder == null) {
            result.error("bad_args", "path, name and folder are needed", null)
            return
        }
        // Copying a big file takes a moment: not on the UI thread.
        Thread {
            val resolver = activity.contentResolver
            var uri: Uri? = null
            try {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, "$name.pdf")
                    put(MediaStore.MediaColumns.MIME_TYPE, PDF_MIME)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, folder)
                    // Hidden from other apps until it is complete.
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                uri = resolver.insert(
                    MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                    values,
                ) ?: throw IllegalStateException("MediaStore refused the file")
                resolver.openOutputStream(uri).use { output ->
                    requireNotNull(output) { "No output stream" }
                    File(path).inputStream().use { it.copyTo(output) }
                }
                resolver.update(
                    uri,
                    ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                    null,
                    null,
                )
                // Android renames it ("... (1).pdf") when the name is taken.
                val savedName = resolver.query(
                    uri,
                    arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                    null,
                    null,
                    null,
                )?.use { cursor ->
                    if (cursor.moveToFirst()) cursor.getString(0) else null
                } ?: "$name.pdf"
                val saved = mapOf("uri" to uri.toString(), "name" to savedName)
                activity.runOnUiThread { result.success(saved) }
            } catch (error: Exception) {
                uri?.let { runCatching { resolver.delete(it, null, null) } }
                activity.runOnUiThread {
                    result.error("save_failed", error.message, null)
                }
            }
        }.start()
    }

    /** true = a file manager opened [folder]; false = none could. */
    private fun openFolder(call: MethodCall, result: MethodChannel.Result) {
        val folder = call.argument<String>("folder").orEmpty()
        val uri = DocumentsContract.buildDocumentUri(
            EXTERNAL_STORAGE_AUTHORITY,
            "primary:$folder",
        )
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, DocumentsContract.Document.MIME_TYPE_DIR)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        result.success(start(intent))
    }

    /** true = a PDF viewer opened the file; false = none could. */
    private fun openPdf(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")?.let(Uri::parse)
        if (uri == null) {
            result.success(false)
            return
        }
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, PDF_MIME)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        result.success(start(intent))
    }

    private fun start(intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (error: ActivityNotFoundException) {
        false
    } catch (error: SecurityException) {
        false
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/documents"
        const val PDF_MIME = "application/pdf"
        const val EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents"
    }
}
