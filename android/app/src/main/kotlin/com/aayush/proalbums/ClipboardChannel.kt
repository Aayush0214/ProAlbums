package com.aayush.proalbums

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentUris
import android.os.Build
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * "Copy to clipboard": puts pictures (their MediaStore address) on the
 * system clipboard, so they can be pasted in a chat, a note, an email...
 * Several pictures go in ONE clip (one item each).
 *
 * Android 13+ shows its own "Copied" confirmation; the answer tells Dart
 * whether it did, so the app shows one itself only on older Android.
 */
class ClipboardChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "copyImages" -> copyImages(call, result)
            else -> result.notImplemented()
        }
    }

    private fun copyImages(call: MethodCall, result: MethodChannel.Result) {
        val uris = call.argument<List<String>>("ids").orEmpty()
            .mapNotNull { it.toLongOrNull() }
            .map {
                ContentUris.withAppendedId(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    it,
                )
            }
        if (uris.isEmpty()) {
            result.error("no_images", "Nothing to copy", null)
            return
        }
        try {
            val clip = ClipData.newUri(activity.contentResolver, "Images", uris.first())
            for (uri in uris.drop(1)) clip.addItem(ClipData.Item(uri))
            val clipboard = activity.getSystemService(ClipboardManager::class.java)
            clipboard.setPrimaryClip(clip)
            result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
        } catch (error: Exception) {
            result.error("copy_failed", error.message, null)
        }
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/clipboard"
    }
}
