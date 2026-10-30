package com.aayush.proalbums

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SystemThumbnailChannel(contentResolver)
            .register(flutterEngine.dartExecutor.binaryMessenger)
    }

    private fun requestHighestRefreshRate() {
        val display = display ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: return

        val params: WindowManager.LayoutParams = window.attributes
        params.preferredDisplayModeId = best.modeId
        params.preferredRefreshRate = best.refreshRate // some OEMs honour this one
        window.attributes = params
    }
}
