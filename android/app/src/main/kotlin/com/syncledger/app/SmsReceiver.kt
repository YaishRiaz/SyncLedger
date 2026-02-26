package com.syncledger.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private var callback: ((sender: String, body: String, timestamp: Long) -> Unit)? = null

        fun setCallback(cb: (sender: String, body: String, timestamp: Long) -> Unit) {
            callback = cb
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val grouped = mutableMapOf<String, StringBuilder>()
        var sender = ""
        var timestamp = System.currentTimeMillis()

        for (msg in messages) {
            sender = msg.originatingAddress ?: ""
            timestamp = msg.timestampMillis
            grouped.getOrPut(sender) { StringBuilder() }.append(msg.messageBody ?: "")
        }

        for ((addr, body) in grouped) {
            callback?.invoke(addr, body.toString(), timestamp)
        }
    }
}
