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
 * Custom FCM service — intercepts all messages before Flutter processes them.
 *
 * new_order / vendor_new_order → rich heads-up notification (Zomato-style).
 * Other messages             → standard high-importance notification.
 *
 * Always calls super() so Flutter's onMessage stream / background handler runs.
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
            "new_order", "vendor_new_order" -> showOrderNotification(message.data)
            else -> showNativeNotification(message)
        }

        // Always propagate — triggers Flutter onMessage / background handler.
        super.onMessageReceived(message)
    }

    // ── Rich order notification (Zomato-style heads-up) ──────────────────────

    private fun showOrderNotification(data: Map<String, String>) {
        val orderNumber  = data["order_number"]  ?: ""
        val customerName = data["customer_name"] ?: ""
        val totalAmount  = data["total_amount"]  ?: data["order_amount"]  ?: ""
        val itemsSummary = data["items_summary"] ?: data["order_items"]   ?: ""
        val orderId      = data["order_id"]      ?: ""

        val title = if (orderNumber.isNotEmpty()) "New Order! #$orderNumber"
                    else "New Order!"

        val body = buildString {
            if (customerName.isNotEmpty()) append(customerName)
            if (itemsSummary.isNotEmpty()) {
                if (isNotEmpty()) append(" • ")
                append(itemsSummary)
            }
            if (totalAmount.isNotEmpty()) {
                if (isNotEmpty()) append(" • ")
                append("₹$totalAmount")
            }
        }.ifEmpty { data["body"] ?: "Tap to view order details." }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val tapIntent = PendingIntent.getActivity(
            this,
            orderId.hashCode(),
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("order_id", orderId)
                putExtra("navigate_to", "orders")
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 300, 150, 300))
            .setContentIntent(tapIntent)
            .build()

        val notifId = orderId.hashCode().takeIf { it != 0 }
            ?: System.currentTimeMillis().toInt()
        manager.notify(notifId, notification)
        Log.i(TAG, "Order notification shown: $title")
    }

    // ── Standard notification for non-order messages ─────────────────────────

    private fun showNativeNotification(message: RemoteMessage) {
        val title = message.notification?.title
            ?: message.data["title"]
            ?: "Zill Restaurant Partner"
        val body = message.notification?.body
            ?: message.data["body"]
            ?: ""

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val tapIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
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

    // ── Ensure notification channel exists (Android 8+) ──────────────────────

    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Order Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "New orders and important vendor notifications"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 150, 300)
            }
            manager.createNotificationChannel(channel)
        }
    }
}
