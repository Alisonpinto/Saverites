package com.example.memoria_flutter

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.memoria_flutter/share_intent"
    private var sharedData: HashMap<String, Any>? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getSharedIntent") {
                result.success(sharedData)
                sharedData = null // clear after reading
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        sharedData?.let {
            channel?.invokeMethod("onSharedIntent", it)
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        if (Intent.ACTION_SEND == action && type != null) {
            if ("text/plain" == type) {
                handleSendText(intent)
            } else {
                handleSendBinary(intent)
            }
        }
    }

    private fun handleSendText(intent: Intent) {
        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        if (sharedText != null) {
            val data = HashMap<String, Any>()
            data["type"] = "text"
            data["text"] = sharedText
            sharedData = data
        }
    }

    private fun handleSendBinary(intent: Intent) {
        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        if (uri != null) {
            val data = HashMap<String, Any>()
            val mimeType = intent.type ?: "*/*"
            data["mimeType"] = mimeType

            // Map mimeType to our general categories: image, video, audio, document
            val type = when {
                mimeType.startsWith("image/") -> "image"
                mimeType.startsWith("video/") -> "video"
                mimeType.startsWith("audio/") -> "audio"
                else -> "document"
            }
            data["type"] = type

            // Copy file to cache and get path
            val cachedFile = copyUriToCache(uri)
            if (cachedFile != null) {
                data["filePath"] = cachedFile.absolutePath
                data["name"] = cachedFile.name
                sharedData = data
            }
        }
    }

    private fun copyUriToCache(uri: Uri): File? {
        try {
            var name = "shared_file"
            val returnCursor = contentResolver.query(uri, null, null, null, null)
            if (returnCursor != null) {
                val nameIndex = returnCursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex != -1 && returnCursor.moveToFirst()) {
                    name = returnCursor.getString(nameIndex)
                }
                returnCursor.close()
            }

            val cacheFile = File(cacheDir, name)
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val outputStream = FileOutputStream(cacheFile)
            val buffer = ByteArray(1024)
            var bytesRead: Int
            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                outputStream.write(buffer, 0, bytesRead)
            }
            inputStream.close()
            outputStream.close()
            return cacheFile
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
}
