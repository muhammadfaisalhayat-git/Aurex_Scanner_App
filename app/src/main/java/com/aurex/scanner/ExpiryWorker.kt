package com.aurex.scanner

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
import com.aurex.scanner.scanner.TextParser
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
            
            for (product in products) {
                try {
                    val expiryStr = product.expDate ?: continue
                    
                    // Use TextParser to handle various formats (dd/MM/yyyy, MM/yyyy, etc)
                    val sortableDate = TextParser.convertToSortable(expiryStr)
                    val expiry = LocalDate.parse(sortableDate, DateTimeFormatter.ofPattern("yyyyMMdd"))
                    val daysLeft = ChronoUnit.DAYS.between(today, expiry)

                    // Milestone days for early warnings
                    val milestoneDays = listOf(45L, 30L, 20L)
                    
                    // Logic: Notify on milestones OR every day if within 15 days OR if already expired
                    val shouldNotify = daysLeft in milestoneDays || daysLeft <= 15

                    if (shouldNotify) {
                        val message = when {
                            daysLeft < 0 -> "EXPIRED! (${Math.abs(daysLeft)} days ago)"
                            daysLeft == 0L -> "Expires TODAY!"
                            else -> "Expires in $daysLeft days"
                        }
                        
                        // 1. Show Mobile Push Notification
                        NotificationHelper.showSystemNotification(
                            applicationContext,
                            if (daysLeft <= 0) "🚨 EXPIRED: ${product.name}" else "⚠️ Expiry Alert: ${product.name}",
                            message,
                            product.name.hashCode()
                        )
                        
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

    private fun triggerEmailAlert(productName: String, message: String, email: String?) {
        // Since Android apps cannot send emails directly without user interaction (intent),
        // we log this event. In a production environment with Firebase, 
        // the `NotificationHelper.sendNotification` above would trigger a 
        // Firebase Cloud Function (Trigger: onWrite to /notifications/) 
        // which then sends the email via SendGrid, Mailgun, or Firebase Extensions.
        android.util.Log.d("ExpiryWorker", "Email alert triggered for $email: $productName - $message")
    }
}
