package com.aurex.scanner.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.lifecycle.lifecycleScope
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import com.aurex.scanner.R
import com.aurex.scanner.ExpiryWorker
import com.google.android.gms.tasks.Tasks
import java.util.concurrent.TimeUnit

import com.aurex.scanner.data.AppDatabase
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.ValueEventListener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Job
import java.io.File

import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.ActionBarDrawerToggle
import androidx.drawerlayout.widget.DrawerLayout
import com.google.android.material.navigation.NavigationView
import com.aurex.scanner.util.FirebaseUtils
import com.aurex.scanner.util.LocaleHelper
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
import android.widget.ScrollView
import com.aurex.scanner.ProductAdapter

class MainActivity : BaseActivity() {
    private lateinit var drawerLayout: DrawerLayout
    private lateinit var navView: NavigationView
    private var syncJob: Job? = null

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
        val txtHeaderTitle = headerView.findViewById<android.widget.TextView>(R.id.txtHeaderTitle)
        val txtUserName = headerView.findViewById<android.widget.TextView>(R.id.txtUserName)

        txtHeaderTitle.setOnClickListener {
            drawerLayout.closeDrawers()
        }

        val currentUser = FirebaseAuth.getInstance().currentUser
        if (currentUser != null) {
            txtUserName.text = currentUser.email ?: "Guest User"
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
        checkAndSyncStatus()

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                showExitConfirmationDialog()
            }
        })
    }

    private fun setupSearch() {
        val searchView = findViewById<androidx.appcompat.widget.SearchView>(R.id.searchViewHome)
        val rvResults = findViewById<RecyclerView>(R.id.rvHomeSearchResults)
        rvResults.layoutManager = LinearLayoutManager(this)
        
        searchView.setOnQueryTextListener(object : androidx.appcompat.widget.SearchView.OnQueryTextListener {
            override fun onQueryTextSubmit(query: String?): Boolean {
                if (!query.isNullOrBlank()) {
                    rvResults.visibility = View.GONE
                    val intent = Intent(this@MainActivity, ProductListActivity::class.java)
                    intent.putExtra("SEARCH_QUERY", query)
                    startActivity(intent)
                }
                searchView.clearFocus()
                return true
            }
            override fun onQueryTextChange(newText: String?): Boolean {
                if (newText.isNullOrBlank()) {
                    rvResults.visibility = View.GONE
                }
                return true
            }
        })
    }

    private fun showImageDialog(product: com.aurex.scanner.data.Product) {
        val path = product.imagePath ?: return
        val file = File(path)
        if (!file.exists()) return

        val dialog = android.app.Dialog(this, android.R.style.Theme_Black_NoTitleBar_Fullscreen)
        val photoView = PhotoView(this)
        photoView.setBackgroundColor(Color.BLACK)
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
            })

        photoView.setOnClickListener { dialog.dismiss() }
        dialog.show()
    }

    private fun highlightDatesOnBitmap(original: Bitmap, product: com.aurex.scanner.data.Product): Bitmap {
        val bitmap = original.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(bitmap)
        val mfgPaint = Paint().apply { color = Color.GREEN; style = Paint.Style.STROKE; strokeWidth = 8f; alpha = 150 }
        val expPaint = Paint().apply { color = Color.RED; style = Paint.Style.STROKE; strokeWidth = 8f; alpha = 150 }

        fun drawBox(boxStr: String?, paint: Paint) {
            boxStr?.split(",")?.takeIf { it.size == 4 }?.let { parts ->
                val left = parts[0].toFloat(); val top = parts[1].toFloat(); val right = parts[2].toFloat(); val bottom = parts[3].toFloat()
                canvas.drawRect(left, top, right, bottom, paint)
                val labelPaint = Paint().apply { color = paint.color; textSize = 50f; typeface = Typeface.DEFAULT_BOLD }
                canvas.drawText(if (paint.color == Color.GREEN) "MFG" else "EXP", left, top - 10f, labelPaint)
            }
        }
        drawBox(product.mfgBox, mfgPaint)
        drawBox(product.expBox, expPaint)
        return bitmap
    }

    private fun showExitConfirmationDialog() {
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.exit_app_title))
            .setMessage(getString(R.string.exit_app_msg))
            .setPositiveButton(getString(R.string.yes)) { _, _ -> finishAffinity() }
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
                val snapshot = try { Tasks.await(userRef.get(), 30, TimeUnit.SECONDS) } catch (e: Exception) { null }
                if (snapshot != null && snapshot.exists()) {
                    val serverProductCodes = snapshot.children.mapNotNull { it.getValue(com.aurex.scanner.data.Product::class.java)?.productCode }.toSet()
                    val localProducts = db.productDao().getAllList()
                    val productsToUpdate = localProducts.filter { it.isSynced != serverProductCodes.contains(it.productCode) }.onEach { it.isSynced = serverProductCodes.contains(it.productCode) }
                    if (productsToUpdate.isNotEmpty()) {
                        db.productDao().updateAll(productsToUpdate)
                    }
                }
            } catch (e: Exception) { Log.e("Sync", "Background sync check failed", e) }
        }
    }

    @androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
    private fun setupNavigation() {
        navView.setNavigationItemSelectedListener { menuItem ->
            when (menuItem.itemId) {
                R.id.nav_scan -> startActivity(Intent(this, ScannerActivity::class.java))
                R.id.nav_history -> startActivity(Intent(this, ProductListActivity::class.java))
                R.id.nav_admin -> startActivity(Intent(this, AdminActivity::class.java))
                R.id.nav_backup -> backupToFirebase()
                R.id.nav_restore -> restoreFromFirebase()
                R.id.nav_language -> switchLanguage()
                R.id.nav_settings -> startActivity(Intent(this, SettingsActivity::class.java))
                R.id.nav_logout -> showLogoutConfirmationDialog()
            }
            drawerLayout.closeDrawers()
            true
        }
    }

    private fun showLogoutConfirmationDialog() {
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.logout_confirm_title))
            .setMessage(getString(R.string.logout_confirm_msg))
            .setPositiveButton(getString(R.string.yes)) { _, _ -> logout() }
            .setNegativeButton(getString(R.string.no), null)
            .show()
    }

    private fun checkAdminStatus() {
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        val currentUser = FirebaseAuth.getInstance().currentUser
        val userEmail = currentUser?.email?.lowercase()?.trim()
        val userId = currentUser?.uid ?: ""
        val btnAdminHome = findViewById<Button>(R.id.btnAdminHome)
        val isAdminSession = prefs.getBoolean("isAdmin", false)
        val initiallyAdmin = userEmail == "admin@aurex.com" || isAdminSession
        navView.menu.findItem(R.id.nav_admin).isVisible = initiallyAdmin
        btnAdminHome.visibility = if (initiallyAdmin) View.VISIBLE else View.GONE

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
        getSharedPreferences("AurexPrefs", MODE_PRIVATE).edit().putBoolean("isAdmin", false).putBoolean("rememberMe", false).apply()
        startActivity(Intent(this, LoginActivity::class.java))
        finish()
    }

    private fun switchLanguage() {
        val currentLang = resources.configuration.locales[0].language
        LocaleHelper.setLocale(this, if (currentLang == "ar") "en" else "ar")
        startActivity(Intent(this, MainActivity::class.java).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK) })
        finish()
    }

    private fun backupToFirebase() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_premium_progress, null)
        val progressBar = dialogView.findViewById<com.google.android.material.progressindicator.LinearProgressIndicator>(R.id.progressBar)
        val txtStatus = dialogView.findViewById<android.widget.TextView>(R.id.txtDialogStatus)
        val txtFraction = dialogView.findViewById<android.widget.TextView>(R.id.txtProgressFraction)
        val btnCancel = dialogView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnCancel)
        val dialog = AlertDialog.Builder(this, R.style.PremiumGlassyDialog).setView(dialogView).setCancelable(false).create()
        dialog.show()
        dialogView.findViewById<View>(R.id.btnBackground).setOnClickListener { dialog.dismiss() }
        syncJob = CoroutineScope(Dispatchers.Main).launch {
            FirebaseUtils.backupToRTDB(this@MainActivity) { current, total, name ->
                if (current == 0) { progressBar.isIndeterminate = true; txtStatus.text = getString(R.string.uploading_items_count, total) }
                else { progressBar.isIndeterminate = false; progressBar.max = total; progressBar.progress = current; txtStatus.text = getString(R.string.backing_up_product, name, current, total) }
                txtFraction.text = getString(R.string.sync_progress_status, current, total)
            }
            dialog.dismiss()
        }
        btnCancel.setOnClickListener { syncJob?.cancel(); dialog.dismiss() }
    }

    private fun restoreFromFirebase() {
        AlertDialog.Builder(this).setTitle(R.string.restore_from_cloud_title).setMessage(R.string.restore_from_cloud_msg).setPositiveButton(R.string.restore) { _, _ -> performActualRestore() }.setNegativeButton(R.string.cancel, null).show()
    }

    private fun performActualRestore() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_premium_progress, null)
        val progressBar = dialogView.findViewById<com.google.android.material.progressindicator.LinearProgressIndicator>(R.id.progressBar)
        val txtStatus = dialogView.findViewById<android.widget.TextView>(R.id.txtDialogStatus)
        val txtFraction = dialogView.findViewById<android.widget.TextView>(R.id.txtProgressFraction)
        dialogView.findViewById<android.widget.TextView>(R.id.txtDialogTitle).text = getString(R.string.restoring_data)
        val dialog = AlertDialog.Builder(this, R.style.PremiumGlassyDialog).setView(dialogView).setCancelable(false).create()
        dialog.show()
        dialogView.findViewById<View>(R.id.btnBackground).setOnClickListener { dialog.dismiss() }
        syncJob = CoroutineScope(Dispatchers.Main).launch {
            FirebaseUtils.restoreFromRTDB(this@MainActivity) { current, total, name ->
                progressBar.isIndeterminate = false; progressBar.max = total; progressBar.progress = current; txtStatus.text = getString(R.string.restoring_product_status, name); txtFraction.text = getString(R.string.sync_progress_status, current, total)
            }
            dialog.dismiss()
        }
        dialogView.findViewById<View>(R.id.btnCancel).setOnClickListener { syncJob?.cancel(); dialog.dismiss() }
    }

    private fun scheduleExpiryCheck() {
        val expiryWorkRequest = PeriodicWorkRequestBuilder<ExpiryWorker>(1, TimeUnit.DAYS).addTag("expiry_check").build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork("expiry_check", ExistingPeriodicWorkPolicy.UPDATE, expiryWorkRequest)
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean { menuInflater.inflate(R.menu.top_menu, menu); return true }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.action_notifications -> { showNotificationsDialog(); true }
            R.id.action_home -> { findViewById<ScrollView>(R.id.mainScrollView)?.smoothScrollTo(0, 0); true }
            else -> super.onOptionsItemSelected(item)
        }
    }
}
