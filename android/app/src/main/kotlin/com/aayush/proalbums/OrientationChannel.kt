package com.aayush.proalbums

import android.app.Activity
import android.content.pm.ActivityInfo
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Lets the photo viewer turn with the PHONE'S SENSOR, even when the system
 * auto-rotate switch is off (the system gallery does the same).
 */
class OrientationChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sensor" -> {
                activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR
                result.success(null)
            }
            "portrait" -> {
                activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "com.aayush.proalbums/orientation"
    }
}
