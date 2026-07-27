package net.vigourtech.dl

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createChatNotificationChannel()
    }

    private fun createChatNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CHAT_MESSAGES_CHANNEL_ID,
            "Chat messages",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "New Discount Link chat message notifications"
            enableVibration(true)
            setShowBadge(true)
        }

        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    companion object {
        private const val CHAT_MESSAGES_CHANNEL_ID = "chat_messages"
    }
}
