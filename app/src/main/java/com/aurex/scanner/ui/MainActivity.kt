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
import androidx.lifecycle.lifecycleScope
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
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.view.ViewGroup
import com.github.chrisbanes.photoview.PhotoView
import com.bumptech.glide.Glide
import com.aurex.scanner.ProductAdapter

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
            FirebaseUtils.getDatabase().getReference("users").child(currentUser.uid)
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

        setupSearch()
        
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

    private fun setupSearch() {
        val searchView = findViewById<androidx.appcompat.widget.SearchView>(R.id.searchViewHome)
        val rvResults = findViewById<RecyclerView>(R.id.rvHomeSearchResults)
        val layoutContent = findViewById<View>(R.id.layoutHomeContent)
        
        rvResults.layoutManager = LinearLayoutManager(this)
        
        searchView.setOnQueryTextListener(object : androidx.appcompat.widget.SearchView.OnQueryTextListener {
            override fun onQueryTextSubmit(query: String?): Boolean {
                searchView.clearFocus()
                return true
            }

            override fun onQueryTextChange(newText: String?): Boolean {
                if (!newText.isNullOrBlank()) {
                    layoutContent.visibility = View.GONE
                    rvResults.visibility = View.VISIBLE
                    loadHomeSearchResults(newText, rvResults)
                } else {
                    layoutContent.visibility = View.VISIBLE
                    rvResults.visibility = View.GONE
                }
                return true
            }
        })
    }

    private fun loadHomeSearchResults(query: String, recyclerView: RecyclerView) {
        val db = AppDatabase.getDatabase(this)
        lifecycleScope.launch(Dispatchers.IO) {
            val allData = db.productDao().getAllList()
            val filtered = allData.filter {
                it.name?.contains(query, ignoreCase = true) == true ||
                it.productCode?.contains(query, ignoreCase = true) == true ||
                it.category?.contains(query, ignoreCase = true) == true
            }
            
            withContext(Dispatchers.Main) {
                recyclerView.adapter = ProductAdapter(
                    filtered,
                    onClick = { product -> 
                        val intent = Intent(this@MainActivity, ResultActivity::class.java)
                        intent.putExtra("data", product)
                        intent.putExtra("VIEW_ONLY", true)
                        startActivity(intent)
                    },
                    onEdit = { product -> 
                        val intent = Intent(this@MainActivity, ResultActivity::class.java)
                        intent.putExtra("data", product)
                        intent.putExtra("VIEW_ONLY", false)
                        startActivity(intent)
                    },
                    onDelete = { _ -> }, // Disabled from home for safety
                    onViewImage = { product -> showImageDialog(product) }
                )
            }
        }
    }

    private fun showImageDialog(product: com.aurex.scanner.data.Product) {
        val path = product.imagePath
        if (path == null) {
            Toast.makeText(this, "No image available", Toast.LENGTH_SHORT).show()
            return
        }
        
        val file = File(path)
        if (!file.exists()) {
            Toast.makeText(this, "Image file not found", Toast.LENGTH_SHORT).show()
            return
        }

        val dialog = android.app.Dialog(this, android.R.style.Theme_Black_NoTitleBar_Fullscreen)
        val photoView = PhotoView(this)
        photoView.setBackgroundColor(Color.BLACK)
        photoView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        dialog.setContentView(photoView)

        Glide.with(this)
            .asBitmap()
            .load(file)
            .into(object : com.bumptech.glide.request.target.CustomTarget<Bitmap>() {
                override fun onResourceReady(resource: Bitmap, transition: com.bumptech.glide.request.transition.Transition<in Bitmap>?) {
                    val highlightedBitmap = highlightDatesOnBitmap(resource, product)
                    photoView.setImageBitmap(highlightedBitmap)
                }
                override fun onLoadCleared(placeholder: android.graphics.drawable.Drawable?) {}
                override fun onLoadFailed(errorDrawable: android.graphics.drawable.Drawable?) {
                    Toast.makeText(this@MainActivity, "Failed to load image", Toast.LENGTH_SHORT).show()
                    dialog.dismiss()
                }
            })

        photoView.setOnClickListener { dialog.dismiss() }
        dialog.show()
    }

    private fun highlightDatesOnBitmap(original: Bitmap, product: com.aurex.scanner.data.Product): Bitmap {
        val bitmap = original.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(bitmap)
        
        val mfgPaint = Paint().apply {
            color = Color.GREEN
            style = Paint.Style.STROKE
            strokeWidth = 8f
            alpha = 150
        }
        
        val expPaint = Paint().apply {
            color = Color.RED
            style = Paint.Style.STROKE
            strokeWidth = 8f
            alpha = 150
        }

        fun drawBox(boxStr: String?, paint: Paint) {
            boxStr?.split(",")?.takeIf { it.size == 4 }?.let { parts ->
                val left = parts[0].toFloat()
                val top = parts[1].toFloat()
                val right = parts[2].toFloat()
                val bottom = parts[3].toFloat()
                canvas.drawRect(left, top, right, bottom, paint)
                
                val labelPaint = Paint().apply {
                    color = paint.color
                    textSize = 50f
                    typeface = Typeface.DEFAULT_BOLD
                }
                canvas.drawText(if (paint.color == Color.GREEN) "MFG" else "EXP", left, top - 10f, labelPaint)
            }
        }

        drawBox(product.mfgBox, mfgPaint)
        drawBox(product.expBox, expPaint)
        
        return bitmap
    }

    private fun setupAdminNotificationEngine() {
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        val isAdmin = prefs.getBoolean("isAdmin", false)
        if (!isAdmin) return

        val adminNotifRef = FirebaseUtils.getDatabase().getReference("notifications").child("admin")
        
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
        adminNotifListener?.let {
            FirebaseUtils.getDatabase().getReference("notifications").child("admin").removeEventListener(it)
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
        val rtdb = FirebaseUtils.getDatabase()
        val userRef = rtdb.getReference("users").child(userId).child("products")
        val db = AppDatabase.getDatabase(this)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Fetch all products from RTDB
                val snapshot = try {
                    Tasks.await(userRef.get(), 30, TimeUnit.SECONDS)
                } catch (e: Exception) {
                    Log.e("Sync", "Initial RTDB sync fetch timed out", e)
                    null
                }

                if (snapshot != null && snapshot.exists()) {
                    val serverProductCodes = snapshot.children.mapNotNull { 
                        it.getValue(com.aurex.scanner.data.Product::class.java)?.productCode 
                    }.toSet()
                    
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
                            Log.d("Sync", "Updated ${productsToUpdate.size} products sync status from RTDB")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("Sync", "Background RTDB sync check failed", e)
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
            FirebaseUtils.getDatabase().getReference("users").child(userId)
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

        val dialogView = layoutInflater.inflate(R.layout.dialog_premium_progress, null)
        val progressBar = dialogView.findViewById<com.google.android.material.progressindicator.LinearProgressIndicator>(R.id.progressBar)
        val txtStatus = dialogView.findViewById<android.widget.TextView>(R.id.txtDialogStatus)
        val txtFraction = dialogView.findViewById<android.widget.TextView>(R.id.txtProgressFraction)
        val btnBackground = dialogView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnBackground)
        val btnCancel = dialogView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnCancel)

        val dialog = AlertDialog.Builder(this, R.style.PremiumGlassyDialog)
            .setView(dialogView)
            .setCancelable(false)
            .create()
        dialog.show()

        btnBackground.setOnClickListener { dialog.dismiss() }

        syncJob = CoroutineScope(Dispatchers.Main).launch {
            FirebaseUtils.backupToRTDB(this@MainActivity) { current, total, name ->
                if (current == 0) {
                    progressBar.isIndeterminate = true
                    txtStatus.text = getString(R.string.uploading_items_count, total)
                } else {
                    progressBar.isIndeterminate = false
                    progressBar.max = total
                    progressBar.progress = current
                    txtStatus.text = getString(R.string.backing_up_product, name, current, total)
                }
                txtFraction.text = getString(R.string.sync_progress_status, current, total)
            }
            dialog.dismiss()
        }
        
        btnCancel.setOnClickListener {
            syncJob?.cancel()
            dialog.dismiss()
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
        val dialogView = layoutInflater.inflate(R.layout.dialog_premium_progress, null)
        val progressBar = dialogView.findViewById<com.google.android.material.progressindicator.LinearProgressIndicator>(R.id.progressBar)
        val txtStatus = dialogView.findViewById<android.widget.TextView>(R.id.txtDialogStatus)
        val txtFraction = dialogView.findViewById<android.widget.TextView>(R.id.txtProgressFraction)
        val btnBackground = dialogView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnBackground)
        val btnCancel = dialogView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnCancel)
        
        dialogView.findViewById<android.widget.TextView>(R.id.txtDialogTitle).text = getString(R.string.restoring_data)

        val dialog = AlertDialog.Builder(this, R.style.PremiumGlassyDialog)
            .setView(dialogView)
            .setCancelable(false)
            .create()
        dialog.show()

        btnBackground.setOnClickListener { dialog.dismiss() }

        syncJob = CoroutineScope(Dispatchers.Main).launch {
            FirebaseUtils.restoreFromRTDB(this@MainActivity) { current, total, name ->
                progressBar.isIndeterminate = false
                progressBar.max = total
                progressBar.progress = current
                txtStatus.text = getString(R.string.restoring_product_status, name)
                txtFraction.text = getString(R.string.sync_progress_status, current, total)
            }
            dialog.dismiss()
        }
        
        btnCancel.setOnClickListener {
            syncJob?.cancel()
            dialog.dismiss()
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
