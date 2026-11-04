package com.aayush.proalbums

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.ExifInterface
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Viewer "More" actions on ONE photo / video:
 *  - name: its file name (for the Rename dialog).
 *  - rename: new name, same extension, same folder. Answers "ok", "exists"
 *    (another file there already has that name), "cancelled" or "failed".
 *  - rotate: a picture turned 90° clockwise by changing its EXIF
 *    orientation (the pixels are not saved again, so nothing is lost; like
 *    the system gallery, the original itself turns). JPEG / PNG / WebP only:
 *    "unsupported" otherwise.
 *  - googleLens: hands the picture to Google Lens (the Google app).
 *  - contactPhoto: Android's "set as contact photo": the Contacts app shows
 *    the contacts, then its own crop screen.
 *
 * Files of other apps (Camera...) can only be changed after Android asks
 * ("Allow ProAlbums to modify this photo?"): MediaStore.createWriteRequest,
 * then the change is tried again.
 */
class MediaEditChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** The change waiting for Android's "allow" answer. */
    private var pendingChange: (() -> String)? = null
    private var pendingResult: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")?.toLongOrNull()
        val video = call.argument<Boolean>("video") ?: false
        if (id == null) {
            result.success(null)
            return
        }
        val uri = uriOf(id, video)
        when (call.method) {
            "name" -> background(result) { info(uri)?.name }
            "rename" -> {
                val name = call.argument<String>("name")?.trim().orEmpty()
                worker.execute {
                    val answer = try {
                        prepareRename(uri, name)
                    } catch (error: Exception) {
                        Prepared.Done("failed")
                    }
                    main.post { finish(answer, result) }
                }
            }
            "rotate" -> worker.execute {
                val answer = try {
                    prepareRotate(uri)
                } catch (error: Exception) {
                    Prepared.Done("failed")
                }
                main.post { finish(answer, result) }
            }
            "googleLens" -> result.success(googleLens(uri))
            "contactPhoto" -> result.success(contactPhoto(uri))
            else -> result.notImplemented()
        }
    }

    // --- rename ------------------------------------------------------------------

    private class Info(val name: String, val folder: String?, val mime: String?)

    private sealed interface Prepared {
        /** Nothing more to ask: the answer. */
        class Done(val answer: String) : Prepared

        /** Try [change]; Android must allow it first when it throws. */
        class Change(val uri: Uri, val change: () -> String) : Prepared
    }

    private fun prepareRename(uri: Uri, base: String): Prepared {
        val info = info(uri) ?: return Prepared.Done("failed")
        if (base.isEmpty()) return Prepared.Done("failed")
        val dot = info.name.lastIndexOf('.')
        val extension = if (dot > 0) info.name.substring(dot) else ""
        val newName = base + extension
        if (newName == info.name) return Prepared.Done("ok")
        if (nameTaken(info.folder, newName, uri)) return Prepared.Done("exists")
        return Prepared.Change(uri) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, newName)
            }
            if (activity.contentResolver.update(uri, values, null, null) > 0) "ok" else "failed"
        }
    }

    /** Another file in [folder] already has [name] (the phone ignores case). */
    private fun nameTaken(folder: String?, name: String, self: Uri): Boolean {
        if (folder == null) return false
        activity.contentResolver.query(
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL),
            arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME),
            "${MediaStore.MediaColumns.RELATIVE_PATH} = ?",
            arrayOf(folder),
            null,
        )?.use { cursor ->
            val selfId = ContentUris.parseId(self)
            while (cursor.moveToNext()) {
                if (cursor.getLong(0) == selfId) continue
                if (cursor.getString(1)?.equals(name, ignoreCase = true) == true) return true
            }
        }
        return false
    }

    // --- rotate ------------------------------------------------------------------

    private fun prepareRotate(uri: Uri): Prepared {
        val info = info(uri) ?: return Prepared.Done("failed")
        if (info.mime !in ROTATABLE) return Prepared.Done("unsupported")
        return Prepared.Change(uri) {
            activity.contentResolver.openFileDescriptor(uri, "rw")!!.use { file ->
                val exif = ExifInterface(file.fileDescriptor)
                val now = exif.getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
                exif.setAttribute(
                    ExifInterface.TAG_ORIENTATION,
                    turnedClockwise(now).toString(),
                )
                exif.saveAttributes()
            }
            // Android reads the new orientation (and makes new thumbnails) once
            // the file is closed; asking it to look again makes sure of it.
            activity.contentResolver.update(uri, ContentValues(), null, null)
            "ok"
        }
    }

    // --- running a change (with Android's permission when needed) ---------------

    private fun finish(prepared: Prepared, result: MethodChannel.Result) {
        when (prepared) {
            is Prepared.Done -> result.success(prepared.answer)
            is Prepared.Change -> worker.execute {
                val answer = try {
                    prepared.change()
                } catch (error: SecurityException) {
                    null // not our file: Android must allow it first
                } catch (error: Exception) {
                    "failed"
                }
                main.post {
                    if (answer != null) result.success(answer) else ask(prepared, result)
                }
            }
        }
    }

    private fun ask(prepared: Prepared.Change, result: MethodChannel.Result) {
        pendingResult?.success("cancelled")
        pendingChange = prepared.change
        pendingResult = result
        try {
            val request = MediaStore.createWriteRequest(
                activity.contentResolver,
                listOf(prepared.uri),
            )
            @Suppress("DEPRECATION")
            activity.startIntentSenderForResult(
                request.intentSender, REQUEST_WRITE, null, 0, 0, 0,
            )
        } catch (error: Exception) {
            pendingChange = null
            pendingResult = null
            result.success("failed")
        }
    }

    /** From MainActivity; true when it was our request. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_WRITE) return false
        val change = pendingChange
        val result = pendingResult ?: return true
        pendingChange = null
        pendingResult = null
        if (resultCode != Activity.RESULT_OK || change == null) {
            result.success("cancelled")
            return true
        }
        worker.execute {
            val answer = try {
                change()
            } catch (error: Exception) {
                "failed"
            }
            main.post { result.success(answer) }
        }
        return true
    }

    // --- handing the picture to other apps ---------------------------------------

    /** true when Google Lens opened. */
    private fun googleLens(uri: Uri): Boolean {
        for (target in LENS_APPS) {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/*"
                putExtra(Intent.EXTRA_STREAM, uri)
                setPackage(target)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            try {
                activity.startActivity(intent)
                return true
            } catch (error: ActivityNotFoundException) {
                // Try the next one.
            }
        }
        return false
    }

    /** true when the Contacts app (or the "Set as" chooser) opened. */
    private fun contactPhoto(uri: Uri): Boolean {
        val mime = info(uri)?.mime ?: "image/jpeg"
        val intent = Intent(Intent.ACTION_ATTACH_DATA).apply {
            setDataAndType(uri, mime)
            putExtra("mimeType", mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        // Straight to the Contacts app when it is there (like the system
        // gallery); otherwise Android's "Set as" list.
        val contacts = activity.packageManager
            .queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            .firstOrNull { it.activityInfo.packageName.contains("contacts", ignoreCase = true) }
        return try {
            if (contacts != null) {
                intent.setClassName(contacts.activityInfo.packageName, contacts.activityInfo.name)
                activity.startActivity(intent)
            } else {
                activity.startActivity(Intent.createChooser(intent, "Set as"))
            }
            true
        } catch (error: ActivityNotFoundException) {
            false
        }
    }

    // --- helpers -----------------------------------------------------------------

    private fun uriOf(id: Long, video: Boolean): Uri = ContentUris.withAppendedId(
        if (video) {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        },
        id,
    )

    private fun info(uri: Uri): Info? = activity.contentResolver.query(
        uri,
        arrayOf(
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.RELATIVE_PATH,
            MediaStore.MediaColumns.MIME_TYPE,
        ),
        null,
        null,
        null,
    )?.use { cursor ->
        if (!cursor.moveToFirst()) return null
        Info(
            name = cursor.getString(0) ?: return null,
            folder = cursor.getString(1),
            mime = cursor.getString(2),
        )
    }

    private fun <T> background(result: MethodChannel.Result, work: () -> T) {
        worker.execute {
            val answer = try {
                work()
            } catch (error: Exception) {
                null
            }
            main.post { result.success(answer) }
        }
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/media_edit"
        const val REQUEST_WRITE = 7206

        val ROTATABLE = setOf("image/jpeg", "image/png", "image/webp")

        // The Google app (Lens lives inside it), then the old Lens app.
        val LENS_APPS = listOf("com.google.android.googlequicksearchbox", "com.google.ar.lens")

        fun turnedClockwise(orientation: Int) = ExifTurn.clockwise(orientation)
    }
}

/** Pure EXIF orientation maths (JVM-tested). */
internal object ExifTurn {
    private val plain = listOf(1, 6, 3, 8)
    private val mirrored = listOf(2, 7, 4, 5)

    /**
     * 90° clockwise in EXIF terms. Plain pictures go 1 → 6 → 3 → 8 → 1;
     * mirrored ones 2 → 7 → 4 → 5 → 2 (same order androidx uses).
     */
    fun clockwise(orientation: Int): Int {
        plain.indexOf(orientation).takeIf { it >= 0 }?.let { return plain[(it + 1) % 4] }
        mirrored.indexOf(orientation).takeIf { it >= 0 }?.let { return mirrored[(it + 1) % 4] }
        return 6 // unknown / undefined = upright, so now turned once
    }
}
