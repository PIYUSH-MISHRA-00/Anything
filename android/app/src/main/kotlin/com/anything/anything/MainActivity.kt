package com.anything.anything

import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mediaChannel = "com.anything.anything/media"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register a freshly-written file with MediaStore so it appears in the
        // Files/Downloads apps immediately. A raw File.writeAsString to
        // Download/ lands on disk but is invisible to any MediaStore-backed
        // browser until scanned — which is why "Export successful" showed a
        // path the user could not find.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanFile" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("no_path", "path is required", null)
                        } else {
                            MediaScannerConnection.scanFile(
                                applicationContext,
                                arrayOf(path),
                                null,
                            ) { _, _ -> }
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
