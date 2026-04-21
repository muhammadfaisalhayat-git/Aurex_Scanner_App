package com.aurex.scanner

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        findViewById<Button>(R.id.btnScan).setOnClickListener {
            startActivity(Intent(this, ScannerActivity::class.java))
        }

        findViewById<Button>(R.id.btnHistory).setOnClickListener {
            startActivity(Intent(this, ProductListActivity::class.java))
        }

        scheduleExpiryCheck()
        requestNotificationPermission()
    }

    private fun scheduleExpiryCheck() {
        val work = PeriodicWorkRequestBuilder<ExpiryWorker>(1, TimeUnit.DAYS).build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "expiry_check",
            ExistingPeriodicWorkPolicy.KEEP,
            work
        )
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }
    }
}
