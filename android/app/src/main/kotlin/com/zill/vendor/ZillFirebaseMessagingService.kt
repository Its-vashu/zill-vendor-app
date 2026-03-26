package com.zill.vendor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Custom FCM service that intercepts messages before Flutter processes them.
 *
 * Responsibilities:
 *  - new_order / vendor_new_order → start [OrderAlarmService] for full-screen
 *    alarm even from terminated state.
 *  - Other data-only messages → show a standard high-importance notification
 *    natively so they appear even when the app is in background/terminated.
 *  - Always call super() so Flutter's onMessage stream / background handler runs.
 *
 * The manifest removes Flutter's default FlutterFirebaseMessagingService and
 * registers this class instead, so FCM routes all messages here first.
 */
class ZillFirebaseMessagingService : FlutterFirebaseMessagingService() {

    companion object {
        private const val TAG = "ZillFCM"
        private const val CHANNEL_ID = "high_importance_channel"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val type = message.data["type"] ?: ""
        Log.i(TAG, "onMessageReceived: type=$type id=${message.messageId}")

        when (type) {
            "new_order", "vendor_new_order" -> startOrderAlarm(message.data)
            else -> showNativeNotification(message)
        }

        // Propagate to Flutter — triggers onMessage stream (foreground) or
        // the @pragma('vm:entry-point') background handler (background/terminated).
        super.onMessageReceived(message)
    }

    // ── Start the alarm foreground service ────────────────────────────────────

    private fun startOrderAlarm(data: Map<String, String>) {
        val intent = Intent(this, OrderAlarmService::class.java).apply {
            putExtra(OrderAlarmService.EXTRA_ORDER_ID,       data["order_id"]      ?: "0")
            putExtra(OrderAlarmService.EXTRA_ORDER_NUMBER,   data["order_number"]  ?: "New Order")
            putExtra(OrderAlarmService.EXTRA_ORDER_AMOUNT,   data["order_amount"]  ?: "")
            putExtra(OrderAlarmService.EXTRA_ORDER_ITEMS,    data["order_items"]   ?: "")
            putExtra(OrderAlarmService.EXTRA_ORDER_CUSTOMER, data["customer_name"] ?: "")
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.i(TAG, "OrderAlarmService started for order ${data["order_id"]}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start OrderAlarmService", e)
        }
    }

    // ── Show a standard notification for non-alarm messages ───────────────────

    private fun showNativeNotification(message: RemoteMessage) {
        val title = message.notification?.title
            ?: message.data["title"]
            ?: "Zill Restaurant Partner"
        val body = message.notification?.body
            ?: message.data["body"]
            ?: ""

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "High Importance Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Order alerts and important vendor notifications"
                enableVibration(true)
            }
            manager.createNotificationChannel(channel)
        }

        val tapIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(tapIntent)
            .build()

        val notifId = message.messageId?.hashCode() ?: System.currentTimeMillis().toInt()
        manager.notify(notifId, notification)
        Log.i(TAG, "Native notification shown: $title")
    }
}
