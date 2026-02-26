package com.syncledger.app

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class SmsPlugin : MethodCallHandler {

    companion object {
        private const val METHOD_CHANNEL = "com.syncledger.sms/methods"
        private const val EVENT_CHANNEL = "com.syncledger.sms/events"
        private const val SMS_PERMISSION_CODE = 1001

        private var instance: SmsPlugin? = null
        private var eventSink: EventChannel.EventSink? = null
        private var pendingResult: MethodChannel.Result? = null

        fun registerWith(engine: FlutterEngine, activity: Activity) {
            val plugin = SmsPlugin()
            plugin.activity = activity
            instance = plugin

            val methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            methodChannel.setMethodCallHandler(plugin)

            val eventChannel = EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

            SmsReceiver.setCallback { sender, body, timestamp ->
                Handler(Looper.getMainLooper()).post {
                    eventSink?.success(
                        mapOf(
                            "sender" to sender,
                            "body" to body,
                            "date" to timestamp
                        )
                    )
                }
            }
        }

        fun getInstance(): SmsPlugin? = instance
    }

    private lateinit var activity: Activity

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestSmsPermission" -> requestSmsPermission(result)
            "getInboxMessages" -> {
                val sinceMs = call.argument<Long>("sinceTimestampMs")
                getInboxMessages(sinceMs, result)
            }
            "startSmsListener" -> {
                result.success(true)
            }
            "stopSmsListener" -> {
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        val permissions = arrayOf(
            Manifest.permission.READ_SMS,
            Manifest.permission.RECEIVE_SMS
        )

        val allGranted = permissions.all {
            ContextCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
        }

        if (allGranted) {
            result.success(true)
            return
        }

        pendingResult = result
        ActivityCompat.requestPermissions(activity, permissions, SMS_PERMISSION_CODE)
    }

    fun handlePermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode == SMS_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults.all {
                it == PackageManager.PERMISSION_GRANTED
            }
            pendingResult?.success(granted)
            pendingResult = null
        }
    }

    private fun getInboxMessages(sinceMs: Long?, result: MethodChannel.Result) {
        Thread {
            try {
                val messages = mutableListOf<Map<String, Any?>>()
                val uri = Uri.parse("content://sms/inbox")
                val selection = if (sinceMs != null) "date >= ?" else null
                val selectionArgs = if (sinceMs != null) arrayOf(sinceMs.toString()) else null

                val cursor: Cursor? = activity.contentResolver.query(
                    uri,
                    arrayOf("_id", "address", "body", "date"),
                    selection,
                    selectionArgs,
                    "date DESC"
                )

                cursor?.use {
                    val addressIdx = it.getColumnIndex("address")
                    val bodyIdx = it.getColumnIndex("body")
                    val dateIdx = it.getColumnIndex("date")

                    while (it.moveToNext()) {
                        val sender = it.getString(addressIdx) ?: ""
                        val body = it.getString(bodyIdx) ?: ""
                        val date = it.getLong(dateIdx)

                        messages.add(
                            mapOf(
                                "sender" to sender,
                                "body" to body,
                                "date" to date
                            )
                        )
                    }
                }

                Handler(Looper.getMainLooper()).post {
                    result.success(messages)
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    result.error("SMS_READ_ERROR", e.message, null)
                }
            }
        }.start()
    }
}
