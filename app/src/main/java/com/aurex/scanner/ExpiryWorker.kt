package com.aurex.scanner

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.aurex.scanner.data.AppDatabase
import com.aurex.scanner.data.Notification
import com.aurex.scanner.util.NotificationHelper
import com.google.firebase.auth.FirebaseAuth
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

class ExpiryWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    override fun doWork(): Result {
        val db = AppDatabase.getDatabase(applicationContext)
        val products = kotlinx.coroutines.runBlocking { db.productDao().getAllList() }
        val currentUser = FirebaseAuth.getInstance().currentUser
        val userId = currentUser?.uid

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val today = LocalDate.now()
            val formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy")
            // 45, 30, 15, 10, 5, 3, 1 days before expiration
            val alertDays = listOf(45L, 30L, 15L, 10L, 5L, 3L, 1L, 0L)

            for (product in products) {
                try {
                    val expiryStr = product.expDate ?: continue
                    val expiry = LocalDate.parse(expiryStr, formatter)
                    val daysLeft = ChronoUnit.DAYS.between(today, expiry)

                    if (daysLeft in alertDays || daysLeft < 0) {
                        val message = when {
                            daysLeft < 0 -> "EXPIRED! (${Math.abs(daysLeft)} days ago)"
                            daysLeft == 0L -> "Expires TODAY!"
                            else -> "Expires in $daysLeft days"
                        }
                        
                        // 1. Show Mobile Push Notification
                        showMobileNotification(product.name, message, daysLeft <= 0)
                        
                        // 2. Add to In-App Notification Feed (Firebase)
                        if (userId != null) {
                            val inAppNotif = Notification(
                                title = if (daysLeft <= 0) "🚨 Expiry Alert: ${product.name}" else "⚠️ Near Expiry: ${product.name}",
                                message = message,
                                timestamp = System.currentTimeMillis(),
                                type = "expiry_alert"
                            )
                            NotificationHelper.sendNotification(userId, inAppNotif)
                        }
                        
                        // 3. Email Alert (Logic)
                        // Note: For a real app, email is best sent from a Cloud Function/Backend 
                        // triggered by Firebase Database change or a scheduled task.
                        // Here we simulate the trigger.
                        triggerEmailAlert(product.name, message, currentUser?.email)
                    }
                } catch (e: Exception) {
                    // Ignore invalid date
                }
            }
        }

        return Result.success()
    }

    private fun showMobileNotification(name: String, message: String, isCritical: Boolean) {
        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = if (isCritical) "expiry_critical" else "expiry_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                if (isCritical) "Critical Expiry Alerts" else "Expiry Alerts",
                if (isCritical) NotificationManager.IMPORTANCE_HIGH else NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                if (isCritical) {
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                }
            }
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(applicationContext, channelId)
            .setContentTitle(if (isCritical) "🚨 EXPIRED: $name" else "⚠️ Expiry Alert: $name")
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(if (isCritical) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                manager.notify(name.hashCode(), notification)
            }
        } else {
            manager.notify(name.hashCode(), notification)
        }
    }

    private fun triggerEmailAlert(productName: String, message: String, email: String?) {
        // Since Android apps cannot send emails directly without user interaction (intent),
        // we log this event. In a production environment with Firebase, 
        // the `NotificationHelper.sendNotification` above would trigger a 
        // Firebase Cloud Function (Trigger: onWrite to /notifications/) 
        // which then sends the email via SendGrid, Mailgun, or Firebase Extensions.
        android.util.Log.d("ExpiryWorker", "Email alert triggered for $email: $productName - $message")
    }
}
