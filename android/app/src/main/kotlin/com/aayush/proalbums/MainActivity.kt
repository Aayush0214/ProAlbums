package com.aayush.proalbums

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import com.aayush.proalbums.vault.VaultChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FragmentActivity: the fingerprint dialog (local_auth, BiometricPrompt)
// needs it.
class MainActivity : FlutterFragmentActivity() {
    private lateinit var trashChannel: TrashChannel
    private lateinit var folderChannel: FolderChannel
    private lateinit var vaultChannel: VaultChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SystemThumbnailChannel(contentResolver)
            .register(flutterEngine.dartExecutor.binaryMessenger)
        OrientationChannel(this)
            .register(flutterEngine.dartExecutor.binaryMessenger)
        VideoFrameChannel(contentResolver)
            .register(flutterEngine.dartExecutor.binaryMessenger)
        trashChannel = TrashChannel(this)
        trashChannel.register(flutterEngine.dartExecutor.binaryMessenger)
        folderChannel = FolderChannel(this)
        folderChannel.register(flutterEngine.dartExecutor.binaryMessenger)
        StorageChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
        ClipboardChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
        DocumentChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
        vaultChannel = VaultChannel(this)
        vaultChannel.register(flutterEngine.dartExecutor.binaryMessenger)
    }

    @Deprecated("Flutter still delivers system-screen results this way")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (::trashChannel.isInitialized &&
            trashChannel.onActivityResult(requestCode, resultCode)
        ) return
        if (::folderChannel.isInitialized &&
            folderChannel.onActivityResult(requestCode, resultCode)
        ) return
        if (::vaultChannel.isInitialized &&
            vaultChannel.onActivityResult(requestCode, resultCode)
        ) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
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
