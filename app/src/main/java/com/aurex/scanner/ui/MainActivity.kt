package com.aurex.scanner.ui

import android.Manifest
import android.content.Intent
import android.content.DialogInterface
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import com.aurex.scanner.R
import com.aurex.scanner.ExpiryWorker
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.tasks.Tasks
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

import com.aurex.scanner.data.AppDatabase
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.Job
import java.io.File
import java.util.Collections

import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.ActionBarDrawerToggle
import androidx.drawerlayout.widget.DrawerLayout
import com.google.android.material.navigation.NavigationView
import com.aurex.scanner.util.FirebaseUtils
import com.aurex.scanner.util.LocaleHelper
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import android.view.View
import com.aurex.scanner.NotificationAdapter
import com.aurex.scanner.data.Notification
import com.aurex.scanner.util.NotificationHelper
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView

class MainActivity : BaseActivity() {
    private lateinit var drawerLayout: DrawerLayout
    private lateinit var navView: NavigationView
    private var syncJob: Job? = null
    private var adminNotifListener: ValueEventListener? = null

    @androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val toolbar = findViewById<androidx.appcompat.widget.Toolbar>(R.id.toolbar)
        setSupportActionBar(toolbar)
        supportActionBar?.title = getString(R.string.app_name)

        drawerLayout = findViewById(R.id.drawer_layout)
        navView = findViewById(R.id.nav_view)

        val toggle = ActionBarDrawerToggle(
            this, drawerLayout, toolbar,
            R.string.navigation_drawer_open, R.string.navigation_drawer_close
        )
        drawerLayout.addDrawerListener(toggle)
        toggle.syncState()

        val headerView = navView.getHeaderView(0)
        val txtUserName = headerView.findViewById<android.widget.TextView>(R.id.txtUserName)
        val currentUser = FirebaseAuth.getInstance().currentUser
        
        if (currentUser != null) {
            // First show email as fallback
            txtUserName.text = currentUser.email ?: "Guest User"
            
            // Try to get name from Database
            val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
            FirebaseDatabase.getInstance(databaseUrl).getReference("users").child(currentUser.uid)
                .addListenerForSingleValueEvent(object : ValueEventListener {
                    override fun onDataChange(snapshot: DataSnapshot) {
                        if (snapshot.exists()) {
                            val user = snapshot.getValue(com.aurex.scanner.data.User::class.java)
                            if (!user?.name.isNullOrEmpty()) {
                                txtUserName.text = user?.name
                            }
                        }
                    }
                    override fun onCancelled(error: DatabaseError) {}
                })
        } else {
            txtUserName.text = "Guest User"
        }

        /* Ad Banner Hidden
        MobileAds.initialize(this) {}
        val adView = findViewById<AdView>(R.id.adView)
        val adRequest = AdRequest.Builder().build()
        adView.loadAd(adRequest)
        */

        setupNavigation()
        checkAdminStatus()

        findViewById<Button>(R.id.btnScanHome).setOnClickListener {
            startActivity(Intent(this, ScannerActivity::class.java))
        }

        findViewById<Button>(R.id.btnHistoryHome).setOnClickListener {
            startActivity(Intent(this, ProductListActivity::class.java))
        }

        findViewById<Button>(R.id.btnNearExpiryHome).setOnClickListener {
            val intent = Intent(this, ProductListActivity::class.java)
            intent.putExtra("FILTER_TYPE", "near_expiry")
            startActivity(intent)
        }

        findViewById<Button>(R.id.btnAdminHome).setOnClickListener {
            startActivity(Intent(this, AdminActivity::class.java))
        }
        
        scheduleExpiryCheck()
        requestNotificationPermission()
        checkAndSyncStatus()
        setupAdminNotificationEngine()

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                showExitConfirmationDialog()
            }
        })
    }

    private fun setupAdminNotificationEngine() {
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        val isAdmin = prefs.getBoolean("isAdmin", false)
        if (!isAdmin) return

        val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
        val adminNotifRef = FirebaseDatabase.getInstance(databaseUrl).getReference("notifications").child("admin")
        
        // Remove existing listener if any
        adminNotifListener?.let { adminNotifRef.removeEventListener(it) }

        adminNotifListener = object : ValueEventListener {
            private var isInitialData = true

            override fun onDataChange(snapshot: DataSnapshot) {
                if (isInitialData) {
                    isInitialData = false
                    return
                }

                // Get the newest notification (last child)
                val lastChild = snapshot.children.lastOrNull()
                val notification = lastChild?.getValue(Notification::class.java)

                if (notification != null && !notification.read) {
                    NotificationHelper.showSystemNotification(
                        this@MainActivity,
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
        
        // Listen only for new entries
        adminNotifRef.limitToLast(1).addValueEventListener(adminNotifListener!!)
    }

    override fun onDestroy() {
        super.onDestroy()
        val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
        adminNotifListener?.let {
            FirebaseDatabase.getInstance(databaseUrl).getReference("notifications").child("admin").removeEventListener(it)
        }
    }

    private fun showExitConfirmationDialog() {
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.exit_app_title))
            .setMessage(getString(R.string.exit_app_msg))
            .setPositiveButton(getString(R.string.yes)) { _, _ ->
                finishAffinity()
            }
            .setNegativeButton(getString(R.string.no), null)
            .show()
    }

    private fun checkAndSyncStatus() {
        val user = FirebaseAuth.getInstance().currentUser ?: return
        val userId = user.uid
        val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
        val productsRef = FirebaseDatabase.getInstance(databaseUrl).getReference("products").child(userId)
        val db = AppDatabase.getDatabase(this)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Fetch all product codes from server with longer timeout
                val snapshot = try {
                    Tasks.await(productsRef.get(), 60, TimeUnit.SECONDS)
                } catch (e: Exception) {
                    Log.e("Sync", "Initial sync fetch timed out", e)
                    null
                }

                if (snapshot != null && snapshot.exists()) {
                    val serverProductCodes = snapshot.children.mapNotNull { it.key }.toSet()
                    val localProducts = db.productDao().getAllList()
                    
                    val productsToUpdate = mutableListOf<com.aurex.scanner.data.Product>()
                    
                    for (localProduct in localProducts) {
                        val shouldBeSynced = serverProductCodes.contains(localProduct.productCode)
                        if (localProduct.isSynced != shouldBeSynced) {
                            localProduct.isSynced = shouldBeSynced
                            productsToUpdate.add(localProduct)
                        }
                    }

                    if (productsToUpdate.isNotEmpty()) {
                        db.productDao().updateAll(productsToUpdate)
                        withContext(Dispatchers.Main) {
                            Log.d("Sync", "Updated ${productsToUpdate.size} products sync status")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("Sync", "Background sync check failed", e)
            }
        }
    }

    @androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
    private fun setupNavigation() {
        navView.setNavigationItemSelectedListener { menuItem ->
            when (menuItem.itemId) {
                R.id.nav_scan -> {
                    startActivity(Intent(this, ScannerActivity::class.java))
                }
                R.id.nav_history -> {
                    startActivity(Intent(this, ProductListActivity::class.java))
                }
                R.id.nav_admin -> {
                    startActivity(Intent(this, AdminActivity::class.java))
                }
                R.id.nav_backup -> {
                    backupToFirebase()
                }
                R.id.nav_restore -> {
                    restoreFromFirebase()
                }
                R.id.nav_language -> {
                    switchLanguage()
                }
                R.id.nav_settings -> {
                    startActivity(Intent(this, SettingsActivity::class.java))
                }
                R.id.nav_logout -> {
                    showLogoutConfirmationDialog()
                }
            }
            drawerLayout.closeDrawers()
            true
        }
    }

    private fun showLogoutConfirmationDialog() {
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.logout_confirm_title))
            .setMessage(getString(R.string.logout_confirm_msg))
            .setPositiveButton(getString(R.string.yes)) { _, _ ->
                logout()
            }
            .setNegativeButton(getString(R.string.no), null)
            .show()
    }

    private fun checkAdminStatus() {
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        val currentUser = FirebaseAuth.getInstance().currentUser
        val userEmail = currentUser?.email?.lowercase()?.trim()
        val userId = currentUser?.uid ?: ""
        val btnAdminHome = findViewById<Button>(R.id.btnAdminHome)
        
        // Initial check from SharedPreferences
        val isAdminSession = prefs.getBoolean("isAdmin", false)
        val initiallyAdmin = userEmail == "admin@aurex.com" || isAdminSession
        navView.menu.findItem(R.id.nav_admin).isVisible = initiallyAdmin
        btnAdminHome.visibility = if (initiallyAdmin) View.VISIBLE else View.GONE

        // Verify with Realtime Database for latest status
        if (userId.isNotEmpty()) {
            val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
            FirebaseDatabase.getInstance(databaseUrl).getReference("users").child(userId)
                .addListenerForSingleValueEvent(object : ValueEventListener {
                    override fun onDataChange(snapshot: DataSnapshot) {
                        val user = snapshot.getValue(com.aurex.scanner.data.User::class.java)
                        val isAdmin = userEmail == "admin@aurex.com" || (user?.isAdmin == true)
                        
                        prefs.edit().putBoolean("isAdmin", isAdmin).apply()
                        navView.menu.findItem(R.id.nav_admin).isVisible = isAdmin
                        btnAdminHome.visibility = if (isAdmin) View.VISIBLE else View.GONE
                    }

                    override fun onCancelled(error: DatabaseError) {}
                })
        }
    }

    private fun logout() {
        FirebaseAuth.getInstance().signOut()
        getSharedPreferences("AurexPrefs", MODE_PRIVATE).edit()
            .putBoolean("isAdmin", false)
            .putBoolean("rememberMe", false)
            .apply()
        startActivity(Intent(this, LoginActivity::class.java))
        finish()
    }

    private fun switchLanguage() {
        val currentLang = resources.configuration.locales[0].language
        val newLang = if (currentLang == "ar") "en" else "ar"

        LocaleHelper.setLocale(this, newLang)

        // Restart activity to apply changes
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        startActivity(intent)
        finish()
    }

    private fun showAdminPasswordDialog() {
        val passwordInput = EditText(this)
        passwordInput.hint = "Enter Admin Password"
        passwordInput.inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD

        AlertDialog.Builder(this)
            .setTitle("Admin Access")
            .setMessage("Please enter the admin password to continue.")
            .setView(passwordInput)
            .setPositiveButton("Login") { _, _ ->
                val password = passwordInput.text.toString()
                if (password == "password") {
                    startActivity(Intent(this, AdminActivity::class.java))
                } else {
                    Toast.makeText(this, "Incorrect Password", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun backupToFirebase() {
        val user = FirebaseAuth.getInstance().currentUser
        if (user == null) {
            Toast.makeText(this, R.string.login, Toast.LENGTH_SHORT).show()
            return
        }

        val userId = user.uid
        val firestore = FirebaseUtils.getFirestore()
        val productsCollection = firestore.collection("backups").document(userId).collection("products")

        val db = AppDatabase.getDatabase(this)
        
        syncJob = CoroutineScope(Dispatchers.Main).launch {
            val progressDialog = AlertDialog.Builder(this@MainActivity, R.style.PremiumGlassyDialog)
                .setTitle(R.string.syncing_data)
                .setMessage(getString(R.string.preparing_backup))
                .setCancelable(false)
                .setNegativeButton(R.string.cancel) { _, _ ->
                    syncJob?.cancel()
                    Toast.makeText(this@MainActivity, R.string.sync_cancelled, Toast.LENGTH_SHORT).show()
                }
                .setNeutralButton(R.string.run_in_background) { dialog, _ ->
                    dialog.dismiss()
                    Toast.makeText(this@MainActivity, R.string.syncing_data, Toast.LENGTH_SHORT).show()
                }
                .create()
            progressDialog.show()

            try {
                val localProducts = withContext(Dispatchers.IO) { db.productDao().getAllList() }
                
                if (localProducts.isEmpty()) {
                    if (progressDialog.isShowing) progressDialog.dismiss()
                    Toast.makeText(this@MainActivity, R.string.no_local_data, Toast.LENGTH_SHORT).show()
                    return@launch
                }

                val totalCount = localProducts.size
                if (progressDialog.isShowing) {
                    progressDialog.setMessage(getString(R.string.uploading_to_firestore, totalCount))
                }
                
                var uploadedCount = 0
                var hasError = false

                for (product in localProducts) {
                    if (syncJob?.isCancelled == true) break
                    
                    if (progressDialog.isShowing) {
                        withContext(Dispatchers.Main) {
                            progressDialog.setMessage(getString(R.string.backing_up_product, product.name, uploadedCount, totalCount))
                        }
                    }

                    val success = withContext(Dispatchers.IO) {
                        try {
                            // Using Firestore set() with merge for reliable updates
                            Tasks.await(productsCollection.document(product.productCode).set(product, SetOptions.merge()), 30, TimeUnit.SECONDS)
                            true
                        } catch (e: Exception) {
                            Log.e("Backup", "Failed to backup ${product.productCode}", e)
                            false
                        }
                    }

                    if (success) {
                        uploadedCount++
                        withContext(Dispatchers.IO) {
                            product.isSynced = true
                            db.productDao().update(product)
                        }
                        NotificationHelper.showProgressNotification(
                            this@MainActivity,
                            getString(R.string.cloud_backup),
                            getString(R.string.uploaded_items, uploadedCount, totalCount),
                            uploadedCount,
                            totalCount,
                            false
                        )
                    } else {
                        hasError = true
                    }
                }

                if (progressDialog.isShowing) progressDialog.dismiss()
                NotificationHelper.cancelNotification(this@MainActivity)

                if (uploadedCount > 0) {
                    AlertDialog.Builder(this@MainActivity)
                        .setTitle(R.string.backup_success_title)
                        .setMessage(getString(R.string.backup_success_msg, uploadedCount) + (if (hasError) "\nSome items failed to upload." else ""))
                        .setPositiveButton(R.string.ok, null)
                        .show()
                } else {
                    Toast.makeText(this@MainActivity, R.string.backup_failed, Toast.LENGTH_LONG).show()
                }

            } catch (e: Exception) {
                if (progressDialog.isShowing) progressDialog.dismiss()
                Log.e("Backup", "General Error", e)
                Toast.makeText(this@MainActivity, "Error: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun restoreFromFirebase() {
        val user = FirebaseAuth.getInstance().currentUser
        if (user == null) {
            Toast.makeText(this, R.string.login, Toast.LENGTH_SHORT).show()
            return
        }

        AlertDialog.Builder(this)
            .setTitle(R.string.restore_from_cloud_title)
            .setMessage(R.string.restore_from_cloud_msg)
            .setPositiveButton(R.string.restore) { _, _ ->
                performActualRestore(user.uid)
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun performActualRestore(userId: String) {
        val firestore = FirebaseUtils.getFirestore()
        val productsCollection = firestore.collection("backups").document(userId).collection("products")
        val db = AppDatabase.getDatabase(this)

        val progressDialog = AlertDialog.Builder(this, R.style.PremiumGlassyDialog)
            .setTitle(R.string.syncing_data)
            .setMessage(getString(R.string.fetching_from_firestore))
            .setCancelable(false)
            .setNegativeButton(R.string.cancel) { _, _ ->
                syncJob?.cancel()
            }
            .setNeutralButton(R.string.run_in_background) { dialog, _ ->
                dialog.dismiss()
                Toast.makeText(this@MainActivity, R.string.syncing_data, Toast.LENGTH_SHORT).show()
            }
            .create()
        progressDialog.show()

        syncJob = CoroutineScope(Dispatchers.Main).launch {
            try {
                val querySnapshot = withContext(Dispatchers.IO) {
                    try {
                        Tasks.await(productsCollection.get(), 60, TimeUnit.SECONDS)
                    } catch (e: Exception) {
                        Log.e("Restore", "Firestore fetch failed", e)
                        null
                    }
                }

                if (querySnapshot == null || querySnapshot.isEmpty) {
                    // FALLBACK: Check old Realtime Database if Firestore is empty
                    if (progressDialog.isShowing) {
                        withContext(Dispatchers.Main) {
                            progressDialog.setMessage(getString(R.string.checking_legacy_server))
                        }
                    }
                    val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
                    val rtdbRef = FirebaseDatabase.getInstance(databaseUrl).getReference("products").child(userId)
                    val rtdbSnapshot = withContext(Dispatchers.IO) {
                        try {
                            Tasks.await(rtdbRef.get(), 30, TimeUnit.SECONDS)
                        } catch (e: Exception) {
                            null
                        }
                    }

                    if (rtdbSnapshot == null || !rtdbSnapshot.exists()) {
                        if (progressDialog.isShowing) progressDialog.dismiss()
                        Toast.makeText(this@MainActivity, R.string.no_backup_found, Toast.LENGTH_LONG).show()
                        return@launch
                    }

                    // Process RTDB data
                    val products = mutableListOf<com.aurex.scanner.data.Product>()
                    for (child in rtdbSnapshot.children) {
                        child.getValue(com.aurex.scanner.data.Product::class.java)?.let { product ->
                            if (product.productCode.isEmpty()) product.productCode = child.key ?: ""
                            product.isSynced = true
                            products.add(product)
                        }
                    }
                    
                    if (products.isNotEmpty()) {
                        withContext(Dispatchers.IO) {
                            db.productDao().deleteAll()
                            db.productDao().insertAll(products)
                        }
                        if (progressDialog.isShowing) progressDialog.dismiss()
                        AlertDialog.Builder(this@MainActivity)
                            .setTitle(R.string.legacy_restore_complete_title)
                            .setMessage(getString(R.string.legacy_restore_complete_msg, products.size))
                            .setPositiveButton(R.string.ok, null)
                            .show()
                        return@launch
                    }
                }

                val products = mutableListOf<com.aurex.scanner.data.Product>()
                val documents = querySnapshot?.documents ?: emptyList()
                val totalItems = documents.size
                var processedItems = 0

                for (doc in documents) {
                    if (syncJob?.isCancelled == true) break
                    
                    doc.toObject(com.aurex.scanner.data.Product::class.java)?.let { product ->
                        product.isSynced = true
                        products.add(product)
                    }
                    
                    processedItems++
                    if (progressDialog.isShowing) {
                        withContext(Dispatchers.Main) {
                            progressDialog.setMessage(getString(R.string.restoring_product, processedItems, totalItems))
                        }
                    }
                    NotificationHelper.showProgressNotification(
                        this@MainActivity,
                        getString(R.string.cloud_restore),
                        getString(R.string.downloading_items, processedItems, totalItems),
                        processedItems,
                        totalItems,
                        false
                    )
                }

                if (syncJob?.isCancelled == true) {
                    if (progressDialog.isShowing) progressDialog.dismiss()
                    NotificationHelper.cancelNotification(this@MainActivity)
                    return@launch
                }

                if (products.isNotEmpty()) {
                    withContext(Dispatchers.IO) {
                        db.productDao().deleteAll()
                        db.productDao().insertAll(products)
                    }
                    
                    if (progressDialog.isShowing) progressDialog.dismiss()
                    NotificationHelper.cancelNotification(this@MainActivity)
                    AlertDialog.Builder(this@MainActivity)
                        .setTitle(R.string.restore_complete_title)
                        .setMessage(getString(R.string.restore_complete_msg, products.size))
                        .setPositiveButton(R.string.ok, null)
                        .show()
                }

            } catch (e: Exception) {
                if (progressDialog.isShowing) progressDialog.dismiss()
                NotificationHelper.cancelNotification(this@MainActivity)
                Log.e("Restore", "Error during restore", e)
                Toast.makeText(this@MainActivity, getString(R.string.restore_failed, e.message), Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun showErrorDialog(title: String, message: String) {
        AlertDialog.Builder(this)
            .setTitle(title)
            .setMessage(message)
            .setPositiveButton("OK", null)
            .show()
    }

    // Helper to use await with Firebase tasks in coroutines
    private suspend fun <T> com.google.android.gms.tasks.Task<T>.await(): T? {
        return kotlin.coroutines.suspendCoroutine { continuation ->
            addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    continuation.resumeWith(Result.success(task.result))
                } else {
                    continuation.resumeWith(Result.failure(task.exception ?: Exception("Unknown task error")))
                }
            }
        }
    }

    private fun scheduleExpiryCheck() {
        val expiryWorkRequest = PeriodicWorkRequestBuilder<ExpiryWorker>(1, TimeUnit.DAYS)
            .setConstraints(Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build())
            .addTag("expiry_check")
            .build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "expiry_check",
            ExistingPeriodicWorkPolicy.UPDATE,
            expiryWorkRequest
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

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.top_menu, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.action_notifications -> {
                showNotificationsDialog()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    private fun showNotificationsDialog() {
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        val isAdmin = prefs.getBoolean("isAdmin", false)
        val currentUser = FirebaseAuth.getInstance().currentUser
        val userId = if (isAdmin) "admin" else currentUser?.uid ?: return
        
        Log.d("Notifications", "Loading notifications for userId: $userId")
        
        val dialogView = layoutInflater.inflate(R.layout.dialog_notifications, null)
        val rvNotifs = dialogView.findViewById<RecyclerView>(R.id.rvNotifications)
        rvNotifs.layoutManager = LinearLayoutManager(this)
        
        val notifList = mutableListOf<Notification>()
        val adapter = NotificationAdapter(notifList) { notif ->
            NotificationHelper.markAsRead(userId, notif.id)
            if (notif.type == "approval" && isAdmin) {
                startActivity(Intent(this, AdminActivity::class.java))
            }
        }
        rvNotifs.adapter = adapter

        val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
        val notifRef = FirebaseDatabase.getInstance(databaseUrl).getReference("notifications").child(userId)
        notifRef.orderByChild("timestamp").limitToLast(50)
            .addValueEventListener(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    notifList.clear()
                    if (!snapshot.exists()) {
                        Log.d("Notifications", "No notifications found in node: $userId")
                    }
                    for (child in snapshot.children) {
                        child.getValue(Notification::class.java)?.let { 
                            it.id = child.key ?: ""
                            notifList.add(0, it) 
                        }
                    }
                    adapter.notifyDataSetChanged()
                }
                override fun onCancelled(error: DatabaseError) {
                    Log.e("Notifications", "Database Error: ${error.message}")
                }
            })

        AlertDialog.Builder(this)
            .setTitle(R.string.notifications) // Added title here
            .setView(dialogView)
            .setPositiveButton(R.string.close, null)
            .show()
    }
}
