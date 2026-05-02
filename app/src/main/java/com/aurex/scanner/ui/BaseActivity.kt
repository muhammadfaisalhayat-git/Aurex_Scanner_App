package com.aurex.scanner.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.aurex.scanner.data.Notification
import com.aurex.scanner.util.FirebaseUtils
import com.aurex.scanner.util.LocaleHelper
import com.aurex.scanner.util.NotificationHelper
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.ValueEventListener

import android.content.Intent
import android.view.MenuItem

open class BaseActivity : AppCompatActivity() {
    private var adminNotifListener: ValueEventListener? = null
    private var userNotifListener: ValueEventListener? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        val mode = prefs.getInt("theme_mode", AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
        AppCompatDelegate.setDefaultNightMode(mode)
        super.onCreate(savedInstanceState)
        
        requestNotificationPermission()
        setupAdminNotificationEngine()
        setupUserNotificationEngine()
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            com.aurex.scanner.R.id.action_home -> {
                if (this !is MainActivity) {
                    val intent = Intent(this, MainActivity::class.java)
                    intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    startActivity(intent)
                }
                true
            }
            android.R.id.home -> {
                onBackPressed()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    private fun setupAdminNotificationEngine() {
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        val isAdmin = prefs.getBoolean("isAdmin", false)
        if (!isAdmin) return

        val adminNotifRef = FirebaseUtils.getDatabase().getReference("notifications").child("admin")
        adminNotifListener?.let { adminNotifRef.removeEventListener(it) }

        adminNotifListener = object : ValueEventListener {
            private var isInitialData = true
            override fun onDataChange(snapshot: DataSnapshot) {
                if (isInitialData) {
                    isInitialData = false
                    return
                }
                val lastChild = snapshot.children.lastOrNull()
                val notification = lastChild?.getValue(Notification::class.java)
                if (notification != null && !notification.read) {
                    NotificationHelper.showSystemNotification(
                        this@BaseActivity,
                        notification.title,
                        notification.message,
                        notification.id.hashCode()
                    )
                }
            }
            override fun onCancelled(error: DatabaseError) {
                Log.e("AdminNotif", "Error: ${error.message}")
            }
        }
        adminNotifRef.limitToLast(1).addValueEventListener(adminNotifListener!!)
    }

    private fun setupUserNotificationEngine() {
        val currentUser = FirebaseAuth.getInstance().currentUser ?: return
        val userId = currentUser.uid
        val userNotifRef = FirebaseUtils.getDatabase().getReference("notifications").child(userId)
        userNotifListener?.let { userNotifRef.removeEventListener(it) }

        userNotifListener = object : ValueEventListener {
            private var isInitialData = true
            override fun onDataChange(snapshot: DataSnapshot) {
                if (isInitialData) {
                    isInitialData = false
                    return
                }
                val lastChild = snapshot.children.lastOrNull()
                val notification = lastChild?.getValue(Notification::class.java)
                if (notification != null && !notification.read) {
                    NotificationHelper.showSystemNotification(
                        this@BaseActivity,
                        notification.title,
                        notification.message,
                        notification.id.hashCode()
                    )
                }
            }
            override fun onCancelled(error: DatabaseError) {
                Log.e("UserNotif", "Error: ${error.message}")
            }
        }
        userNotifRef.limitToLast(1).addValueEventListener(userNotifListener!!)
    }

    override fun onDestroy() {
        super.onDestroy()
        adminNotifListener?.let {
            FirebaseUtils.getDatabase().getReference("notifications").child("admin").removeEventListener(it)
        }
        userNotifListener?.let {
            val userId = FirebaseAuth.getInstance().currentUser?.uid
            if (userId != null) {
                FirebaseUtils.getDatabase().getReference("notifications").child(userId).removeEventListener(it)
            }
        }
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

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(LocaleHelper.onAttach(newBase))
    }
}
