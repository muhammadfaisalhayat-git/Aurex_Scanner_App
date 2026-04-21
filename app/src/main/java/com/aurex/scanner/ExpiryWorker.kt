package com.aurex.scanner

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.aurex.scanner.data.AppDatabase
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

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val today = LocalDate.now()
            val formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy")

            for (product in products) {
                try {
                    val expiryStr = product.expDate ?: continue
                    val expiry = LocalDate.parse(expiryStr, formatter)
                    val daysLeft = ChronoUnit.DAYS.between(today, expiry)

                    if (daysLeft in 0..3) {
                        showNotification(product.name, expiryStr)
                    }
                } catch (e: Exception) {
                    // Skip if date format is invalid
                }
            }
        }

        return Result.success()
    }

    private fun showNotification(name: String, date: String) {
        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "expiry_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Expiry Alerts", NotificationManager.IMPORTANCE_DEFAULT)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(applicationContext, channelId)
            .setContentTitle("⚠️ Expiry Alert")
            .setContentText("$name expires on $date")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setAutoCancel(true)
            .build()

        manager.notify(name.hashCode(), notification)
    }
}
