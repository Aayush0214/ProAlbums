package com.aayush.proalbums

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Albums as REAL folders: every album is the folder Pictures/<name>.
 *
 *  - createFolder: makes the folder (also when it stays empty).
 *  - listFolders: the folders inside Pictures (so empty albums can be shown).
 *  - transfer: Copy (new file in the album) or Move (the file's folder is
 *    changed in MediaStore, so it keeps its id, date and favorite). An
 *    existing album's folder is looked up by its bucket id (DCIM/Camera,
 *    Movies, …); a new / empty album is Pictures/<name>.
 *
 * Move needs write access to files of other apps, so every move goes through
 * MediaStore.createWriteRequest: with "Media management" (turned on once in
 * Settings) Android grants it silently, otherwise it asks once per move
 * ("Allow ProAlbums to modify these?").
 */
class FolderChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private class Item(val uri: Uri, val video: Boolean)

    private var pendingItems: List<Item>? = null
    private var pendingPath: String? = null
    private var pendingResult: MethodChannel.Result? = null

    /** Also used to send transfer progress back to Dart. */
    private var channel: MethodChannel? = null

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createFolder" -> createFolder(call, result)
            "listFolders" -> result.success(listFolders())
            "isPicturesFolder" -> result.success(
                File(picturesDir(), call.argument<String>("name").orEmpty())
                    .let { it.isDirectory && it.parentFile == picturesDir() },
            )
            "renameFolder" -> renameFolder(call, result)
            "removeIfEmpty" -> {
                val name = call.argument<String>("name").orEmpty()
                // Forget the name FIRST: even when the folder cannot be removed
                // (hidden ".trashed" files stay inside) it must stop being listed
                // as an app-made empty album.
                forget(name)
                val dir = File(picturesDir(), name)
                if (dir.isDirectory && dir.list().isNullOrEmpty()) dir.delete()
                result.success(null)
            }
            "transfer" -> transfer(call, result)
            "existingIds" -> existingIds(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Which of the given media ids are really there: not deleted and NOT in
     * Android's trash. (Looking a picture up by its id can still find one
     * that is in the trash, so the favorites ask this first.)
     */
    private fun existingIds(call: MethodCall, result: MethodChannel.Result) {
        val ids = call.argument<List<String>>("ids").orEmpty()
            .mapNotNull { it.toLongOrNull() }
        worker.execute {
            val found = ArrayList<String>()
            try {
                val args = android.os.Bundle().apply {
                    putInt(
                        MediaStore.QUERY_ARG_MATCH_TRASHED,
                        MediaStore.MATCH_EXCLUDE,
                    )
                }
                for (chunk in ids.chunked(400)) {
                    args.putString(
                        android.content.ContentResolver.QUERY_ARG_SQL_SELECTION,
                        "${MediaStore.MediaColumns._ID} IN (${chunk.joinToString(",")})",
                    )
                    activity.contentResolver.query(
                        MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL),
                        arrayOf(MediaStore.MediaColumns._ID),
                        args,
                        null,
                    )?.use { cursor ->
                        while (cursor.moveToNext()) found.add(cursor.getLong(0).toString())
                    }
                }
            } catch (error: Exception) {
                // Cannot ask: answer "all of them" rather than hide the favorites.
                found.clear()
                ids.forEach { found.add(it.toString()) }
            }
            main.post { result.success(found) }
        }
    }

    private fun picturesDir(): File =
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)

    private fun createFolder(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")?.trim().orEmpty()
        if (name.isEmpty() || name.contains('/') || name.contains('\\')) {
            result.error("bad_name", "Invalid album name", null)
            return
        }
        val folder = File(picturesDir(), name)
        // A deleted album leaves its folder behind (Android keeps the deleted
        // pictures inside as hidden ".trashed-..." files for 30 days). Such a
        // folder holds nothing visible, so the name is free to use again.
        val reusable = folder.isDirectory &&
            folder.list()?.none { !it.startsWith(".") } != false
        when {
            reusable -> {
                remember(name)
                result.success("created")
            }
            folder.exists() -> result.success("exists")
            folder.mkdirs() -> {
                remember(name)
                result.success("created")
            }
            else -> result.error("create_failed", "Could not create $folder", null)
        }
    }

    // Folders THIS app made. Only these are listed while they are empty:
    // the phone has many other empty folders (apps make them) that must not
    // show up as albums.
    private val prefs by lazy {
        activity.getSharedPreferences("album_folders", Activity.MODE_PRIVATE)
    }

    private fun remember(name: String) {
        val all = prefs.getStringSet(KEY_CREATED, emptySet()).orEmpty().toMutableSet()
        all.add(name)
        prefs.edit().putStringSet(KEY_CREATED, all).apply()
    }

    private fun forget(name: String) {
        val all = prefs.getStringSet(KEY_CREATED, emptySet()).orEmpty().toMutableSet()
        if (all.remove(name)) prefs.edit().putStringSet(KEY_CREATED, all).apply()
    }

    /** Renames an (empty) folder directly: there are no files to move. */
    private fun renameFolder(call: MethodCall, result: MethodChannel.Result) {
        val from = call.argument<String>("from").orEmpty()
        val to = call.argument<String>("to")?.trim().orEmpty()
        val source = File(picturesDir(), from)
        val target = File(picturesDir(), to)
        if (to.isEmpty() || to.contains('/') || to.contains('\\') ||
            !source.isDirectory || target.exists()
        ) {
            result.success(false)
            return
        }
        val ok = source.renameTo(target)
        if (ok) {
            val all = prefs.getStringSet(KEY_CREATED, emptySet()).orEmpty().toMutableSet()
            all.remove(from)
            all.add(to)
            prefs.edit().putStringSet(KEY_CREATED, all).apply()
        }
        result.success(ok)
    }

    private fun listFolders(): List<String> {
        val created = prefs.getStringSet(KEY_CREATED, emptySet()).orEmpty()
        return created
            .filter { name ->
                val dir = File(picturesDir(), name)
                // Nothing VISIBLE inside: a new album, or one whose pictures were
                // deleted (they wait in Recently deleted). Both stay as blank albums.
                dir.isDirectory && !hasVisibleFiles(dir)
            }
            .sorted()
    }

    private fun transfer(call: MethodCall, result: MethodChannel.Result) {
        val ids = call.argument<List<String>>("ids").orEmpty()
        val videos = call.argument<List<Boolean>>("videos").orEmpty()
        val albumId = call.argument<String>("albumId")
        val folder = call.argument<String>("folder")?.trim().orEmpty()
        val move = call.argument<Boolean>("move") ?: false
        if (ids.isEmpty() || ids.size != videos.size || folder.isEmpty() ||
            folder.contains('/') || folder.contains('\\')
        ) {
            result.error("bad_args", "ids, videos and folder are needed", null)
            return
        }

        val items = ids.indices.mapNotNull { i ->
            val id = ids[i].toLongOrNull() ?: return@mapNotNull null
            Item(ContentUris.withAppendedId(baseUri(videos[i]), id), videos[i])
        }
        if (items.isEmpty()) {
            result.error("bad_ids", "No valid ids", null)
            return
        }

        // Finding the album's folder is a MediaStore query: not on the main thread.
        worker.execute {
            val path = albumPath(albumId, folder)
            if (path == picturesPath(folder)) File(picturesDir(), folder).mkdirs()
            // Move changes files of other apps (Camera...), so it always asks
            // Android for write access first. With "Media management" on, the
            // request is granted at once WITHOUT a dialog; it does NOT allow
            // writing without asking (a direct update then fails with a
            // SecurityException, which is why Camera photos would not move).
            if (move) {
                main.post { askWrite(items, path, result) }
            } else {
                run(items, path, move, result)
            }
        }
    }

    private fun picturesPath(folder: String) = "Pictures/$folder/"

    /**
     * The folder (RELATIVE_PATH, e.g. "DCIM/Camera/") of an existing album,
     * read from any file in it. An album is a MediaStore bucket and can live
     * anywhere, so it must NOT be guessed as Pictures/<name>: that would make
     * a second "Camera" folder. A new / empty album has no file to ask, so it
     * is Pictures/<folder>.
     */
    private fun albumPath(albumId: String?, folder: String): String {
        val bucket = albumId?.toLongOrNull() ?: return picturesPath(folder)
        try {
            val args = android.os.Bundle().apply {
                putString(
                    android.content.ContentResolver.QUERY_ARG_SQL_SELECTION,
                    "${MediaStore.MediaColumns.BUCKET_ID} = ?",
                )
                putStringArray(
                    android.content.ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS,
                    arrayOf(bucket.toString()),
                )
                putInt(android.content.ContentResolver.QUERY_ARG_LIMIT, 1)
            }
            activity.contentResolver.query(
                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL),
                arrayOf(MediaStore.MediaColumns.RELATIVE_PATH),
                args,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val path = cursor.getString(0)
                    if (!path.isNullOrBlank()) return path
                }
            }
        } catch (error: Exception) {
            // Cannot ask: use Pictures/<folder> below.
        }
        return picturesPath(folder)
    }

    private fun baseUri(video: Boolean): Uri =
        if (video) MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        else MediaStore.Images.Media.EXTERNAL_CONTENT_URI

    private fun run(
        items: List<Item>,
        path: String,
        move: Boolean,
        result: MethodChannel.Result,
    ) {
        worker.execute {
            var done = 0
            var failed = 0
            var lastSent = 0L
            val total = items.size
            sendProgress(0, total)
            for (item in items) {
                val ok = try {
                    if (move) moveOne(item, path) else copyOne(item, path)
                } catch (error: Exception) {
                    false
                }
                if (ok) done++ else failed++
                // "12 of 32" for the dialog. At most ~30 updates a second, so
                // thousands of files do not flood the UI thread.
                val now = System.currentTimeMillis()
                val processed = done + failed
                if (processed == total || now - lastSent >= PROGRESS_EVERY_MS) {
                    lastSent = now
                    sendProgress(processed, total)
                }
            }
            main.post {
                result.success(
                    mapOf("status" to "done", "done" to done, "failed" to failed),
                )
            }
        }
    }

    private fun sendProgress(processed: Int, total: Int) {
        main.post {
            channel?.invokeMethod(
                "transferProgress",
                mapOf("done" to processed, "total" to total),
            )
        }
    }

    private fun moveOne(item: Item, path: String): Boolean {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.RELATIVE_PATH, path)
        }
        return activity.contentResolver.update(item.uri, values, null, null) > 0
    }

    private fun copyOne(item: Item, path: String): Boolean {
        val resolver = activity.contentResolver
        val projection = arrayOf(
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.DATE_TAKEN,
        )
        var name: String? = null
        var mime: String? = null
        var taken: Long? = null
        resolver.query(item.uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                name = cursor.getString(0)
                mime = cursor.getString(1)
                if (!cursor.isNull(2)) taken = cursor.getLong(2)
            }
        }
        val fileName = name ?: return false

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, path)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
            taken?.let { put(MediaStore.MediaColumns.DATE_TAKEN, it) }
        }
        val target = resolver.insert(baseUri(item.video), values) ?: return false
        try {
            resolver.openInputStream(item.uri)?.use { input ->
                resolver.openOutputStream(target)?.use { output ->
                    input.copyTo(output)
                } ?: error("no output")
            } ?: error("no input")
            val done = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(target, done, null, null)
            return true
        } catch (error: Exception) {
            resolver.delete(target, null, null) // no half-written copy
            return false
        }
    }

    /** Android's "Allow ProAlbums to modify these files?" dialog. */
    private fun askWrite(
        items: List<Item>,
        path: String,
        result: MethodChannel.Result,
    ) {
        pendingResult?.success(mapOf("status" to "cancelled"))
        pendingItems = items
        pendingPath = path
        pendingResult = result
        try {
            val request = MediaStore.createWriteRequest(
                activity.contentResolver, items.map { it.uri },
            )
            @Suppress("DEPRECATION")
            activity.startIntentSenderForResult(
                request.intentSender, REQUEST_WRITE, null, 0, 0, 0,
            )
        } catch (error: Exception) {
            pendingResult = null
            result.error("write_request_failed", error.message, null)
        }
    }

    /** MainActivity forwards the answer of the system screen here. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_WRITE) return false
        val items = pendingItems
        val path = pendingPath
        val result = pendingResult
        pendingItems = null
        pendingPath = null
        pendingResult = null
        if (items == null || path == null || result == null) return true
        if (resultCode == Activity.RESULT_OK) {
            run(items, path, true, result)
        } else {
            result.success(mapOf("status" to "cancelled"))
        }
        return true
    }

    /** The folder holds something the person can see. Hidden ".trashed-…" files
     *  (Android's trash) do not count. */
    private fun hasVisibleFiles(dir: File): Boolean =
        dir.list()?.any { !it.startsWith(".") } == true

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/folders"
        const val REQUEST_WRITE = 7103
        const val PROGRESS_EVERY_MS = 33L
        const val KEY_CREATED = "created"
    }
}
