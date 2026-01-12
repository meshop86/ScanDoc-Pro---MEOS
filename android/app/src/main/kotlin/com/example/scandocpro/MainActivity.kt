package com.example.scandocpro

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import net.lingala.zip4j.ZipFile
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val ZIP_CHANNEL = "com.scandocpro.zip/native"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ZIP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "zipFolder" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val outputPath = call.argument<String>("outputPath")

                    if (sourcePath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                        return@setMethodCallHandler
                    }

                    zipFolder(sourcePath, outputPath, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun zipFolder(sourcePath: String, outputPath: String, result: MethodChannel.Result) {
        executor.execute {
            try {
                val sourceFile = File(sourcePath)
                val zipFile = ZipFile(outputPath)
                
                if (sourceFile.isDirectory) {
                    zipFile.addFolder(sourceFile)
                } else {
                    zipFile.addFile(sourceFile)
                }

                mainHandler.post {
                    result.success(outputPath)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("ZIP_FAILED", "Failed to create ZIP: ${e.message}", null)
                }
            }
        }
    }
}
