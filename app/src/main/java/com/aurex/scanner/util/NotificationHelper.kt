package com.aurex.scanner.util

import com.aurex.scanner.data.Notification
import com.google.firebase.database.FirebaseDatabase

object NotificationHelper {
    private val db = FirebaseUtils.getDatabase().getReference("notifications")

    /**
     * Sends a notification to a specific user and ALWAYS copies it to the admin feed.
     */
    fun sendNotification(targetUserId: String?, notification: Notification) {
        // 1. Send to specific user if provided
        if (targetUserId != null && targetUserId != "admin") {
            val userRef = db.child(targetUserId).push()
            notification.id = userRef.key ?: ""
            userRef.setValue(notification)
        }

        // 2. ALWAYS send a copy to the admin feed
        val adminRef = db.child("admin").push()
        val adminNotif = notification.copy() // Create a copy for the admin node
        adminNotif.id = adminRef.key ?: ""
        // Tag admin notifications with the original user context if helpful
        if (targetUserId != null && targetUserId != "admin") {
            adminNotif.title = "[User Feed] ${notification.title}"
        }
        adminRef.setValue(adminNotif)
    }

    fun markAsRead(userId: String, notificationId: String) {
        db.child(userId).child(notificationId).child("read").setValue(true)
    }

    fun showSystemNotification(context: android.content.Context, title: String, message: String, notificationId: Int = (System.currentTimeMillis() % 10000).toInt()) {
        val channelId = "general_notifications_channel"
        val channelName = "General Notifications"
        val notificationManager = context.getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(channelId, channelName, android.app.NotificationManager.IMPORTANCE_HIGH).apply {
                description = "General App Notifications"
                enableLights(true)
                lightColor = android.graphics.Color.GREEN
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val intent = android.content.Intent(context, com.aurex.scanner.ui.MainActivity::class.java).apply {
            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = android.app.PendingIntent.getActivity(context, 0, intent, android.app.PendingIntent.FLAG_IMMUTABLE)

        val builder = androidx.core.app.NotificationCompat.Builder(context, channelId)
            .setSmallIcon(com.aurex.scanner.R.drawable.ic_notifications)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
            .setCategory(androidx.core.app.NotificationCompat.CATEGORY_ALARM)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        notificationManager.notify(notificationId, builder.build())
    }

    fun showProgressNotification(context: android.content.Context, title: String, message: String, progress: Int, max: Int, isIndeterminate: Boolean, notificationId: Int = 1001) {
        val channelId = "backup_restore_channel"
        val notificationManager = context.getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(channelId, "Backup & Restore", android.app.NotificationManager.IMPORTANCE_DEFAULT)
            notificationManager.createNotificationChannel(channel)
        }

        val builder = androidx.core.app.NotificationCompat.Builder(context, channelId)
            .setSmallIcon(com.aurex.scanner.R.drawable.ic_notifications)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_LOW) // Use LOW to avoid sound every update
            .setOngoing(max > 0 || isIndeterminate)
            .setProgress(max, progress, isIndeterminate)
            .setAutoCancel(!isIndeterminate && progress == max)

        notificationManager.notify(notificationId, builder.build())
    }

    fun cancelNotification(context: android.content.Context, notificationId: Int = 1001) {
        val notificationManager = context.getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.cancel(notificationId)
    }
}
