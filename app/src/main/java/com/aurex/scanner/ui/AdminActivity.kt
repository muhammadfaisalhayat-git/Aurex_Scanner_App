package com.aurex.scanner.ui

import android.graphics.*
import android.os.Bundle
import android.view.View
import android.widget.*
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import com.aurex.scanner.R
import com.aurex.scanner.UserAdapter
import com.aurex.scanner.ProductAdapter
import com.aurex.scanner.data.*
import com.aurex.scanner.scanner.TextParser
import com.google.android.material.tabs.TabLayout
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.*
import com.google.firebase.firestore.FirebaseFirestore
import com.aurex.scanner.util.FirebaseUtils
import com.aurex.scanner.util.NotificationHelper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AdminActivity : BaseActivity() {

    private lateinit var rvProducts: RecyclerView
    private lateinit var rvUsers: RecyclerView
    private lateinit var layoutProducts: View
    private lateinit var layoutUsers: View
    private lateinit var tabs: TabLayout
    
    private lateinit var txtTotal: TextView
    private lateinit var txtExpired: TextView
    private lateinit var txtNearExpiry: TextView

    private lateinit var cardTotal: View
    private lateinit var cardExpired: View
    private lateinit var cardNearExpiry: View

    private lateinit var layoutAnalyticsContent: View
    private lateinit var imgExpandAnalytics: ImageView
    private lateinit var chartDonutStatus: FrameLayout
    private lateinit var chartPieCategory: FrameLayout
    private lateinit var chartCircleWarehouse: FrameLayout

    private var allAdminProducts = listOf<Product>()
    private var currentFilter = "all"
    
    private val usersList = mutableListOf<User>()
    private lateinit var userAdapter: UserAdapter
    private val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
    private val database = FirebaseDatabase.getInstance(databaseUrl)
    private val usersRef = database.getReference("users")

    private lateinit var swipeRefresh: androidx.swiperefreshlayout.widget.SwipeRefreshLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_admin)

        // Views
        layoutProducts = findViewById(R.id.layoutProducts)
        layoutUsers = findViewById(R.id.layoutUsers)
        tabs = findViewById(R.id.adminTabs)
        swipeRefresh = findViewById(R.id.swipeRefreshProducts)
        
        txtTotal = findViewById(R.id.txtTotalProducts)
        txtExpired = findViewById(R.id.txtExpiredCount)
        txtNearExpiry = findViewById(R.id.txtNearExpiryCount)
        
        cardTotal = findViewById(R.id.cardTotalItems)
        cardExpired = findViewById(R.id.cardExpiredItems)
        cardNearExpiry = findViewById(R.id.cardNearExpiryItems)
        
        layoutAnalyticsContent = findViewById(R.id.layoutAnalyticsContent)
        imgExpandAnalytics = findViewById(R.id.imgExpandAnalytics)
        chartDonutStatus = findViewById(R.id.chartDonutStatus)
        chartPieCategory = findViewById(R.id.chartPieCategory)
        chartCircleWarehouse = findViewById(R.id.chartCircleWarehouse)

        findViewById<View>(R.id.cardAdvancedAnalytics).setOnClickListener {
            toggleAnalytics()
        }
        
        rvProducts = findViewById(R.id.rvAdminProducts)
        rvProducts.layoutManager = LinearLayoutManager(this)
        
        rvUsers = findViewById(R.id.rvAdminUsers)
        rvUsers.layoutManager = LinearLayoutManager(this)
        
        userAdapter = UserAdapter(usersList, 
            onEdit = { user -> showUserDialog(user) },
            onDelete = { user -> confirmDeleteUser(user) }
        )
        rvUsers.adapter = userAdapter

        findViewById<Button>(R.id.btnAddUser).setOnClickListener { showUserDialog(null) }

        setupTabs()
        setupClickListeners()
        
        swipeRefresh.setOnRefreshListener {
            loadDashboardData()
        }

        loadDashboardData()
        observeUsers()
        checkCurrentAdmin()
    }

    private fun setupClickListeners() {
        cardTotal.setOnClickListener {
            currentFilter = "all"
            updateFilteredList()
        }
        cardExpired.setOnClickListener {
            currentFilter = "expired"
            updateFilteredList()
        }
        cardNearExpiry.setOnClickListener {
            currentFilter = "near_expiry"
            updateFilteredList()
        }
    }

    private fun updateFilteredList() {
        val filtered = when (currentFilter) {
            "expired" -> allAdminProducts.filter { TextParser.isExpired(it.expDate) }
            "near_expiry" -> allAdminProducts.filter { TextParser.isNearExpiry(it.expDate) }
            else -> allAdminProducts
        }
        
        rvProducts.adapter = ProductAdapter(filtered, 
            onClick = { product ->
                val intent = android.content.Intent(this@AdminActivity, ResultActivity::class.java)
                intent.putExtra("data", product)
                intent.putExtra("VIEW_ONLY", true)
                startActivity(intent)
            },
            onEdit = {},
            onDelete = { product -> confirmDeleteProduct(product) },
            onViewImage = {}
        )
        
        // Optional: Visual feedback for active filter
        cardTotal.alpha = if (currentFilter == "all") 1.0f else 0.6f
        cardExpired.alpha = if (currentFilter == "expired") 1.0f else 0.6f
        cardNearExpiry.alpha = if (currentFilter == "near_expiry") 1.0f else 0.6f
    }

    private fun checkCurrentAdmin() {
        val user = FirebaseAuth.getInstance().currentUser
        val userEmail = user?.email?.lowercase()?.trim()
        val isAdminSession = getSharedPreferences("AurexPrefs", MODE_PRIVATE).getBoolean("isAdmin", false)

        if (user == null || (userEmail != "admin@aurex.com" && !isAdminSession)) {
            Toast.makeText(this, "Access Denied: Admin only", Toast.LENGTH_LONG).show()
            finish()
        }
    }


    private fun setupTabs() {
        tabs.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab?) {
                if (tab?.position == 0) {
                    layoutProducts.visibility = View.VISIBLE
                    layoutUsers.visibility = View.GONE
                } else {
                    layoutProducts.visibility = View.GONE
                    layoutUsers.visibility = View.VISIBLE
                }
            }
            override fun onTabUnselected(tab: TabLayout.Tab?) {}
            override fun onTabReselected(tab: TabLayout.Tab?) {}
        })
    }

    private fun observeUsers() {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        usersRef.addValueEventListener(object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                usersList.clear()
                for (child in snapshot.children) {
                    try {
                        val user = child.getValue(User::class.java)
                        if (user != null) {
                            user.id = child.key ?: ""
                            
                            // Fetch daily scans for this user
                            val dailyScans = child.child("dailyActivity").child(today).child("scans").getValue(Int::class.java) ?: 0
                            user.dailyScans = dailyScans

                            usersList.add(user)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("AdminActivity", "Error parsing user: ${child.key}", e)
                    }
                }
                // Sort users: Unapproved first, then by name
                usersList.sortWith(compareBy({ it.isApproved }, { it.name }))
                userAdapter.notifyDataSetChanged()
            }
            override fun onCancelled(error: DatabaseError) {
                android.util.Log.e("AdminActivity", "Database Error: ${error.message}")
            }
        })
    }

    private fun showUserDialog(user: User?) {
        val view = layoutInflater.inflate(R.layout.dialog_add_user, null)
        val editName = view.findViewById<EditText>(R.id.editUserName)
        val editEmail = view.findViewById<EditText>(R.id.editUserEmail)
        val editPass = view.findViewById<EditText>(R.id.editUserPassword)
        val editPos = view.findViewById<EditText>(R.id.editUserPosition)
        val cbIsAdmin = view.findViewById<CheckBox>(R.id.cbIsAdmin)

        if (user != null) {
            editName.setText(user.name)
            editEmail.setText(user.email)
            editEmail.isEnabled = false // Don't change email for existing user
            editPass.visibility = View.GONE // Don't show password for edit
            editPos.setText(user.position)
            cbIsAdmin.isChecked = user.isAdmin
            
            if (!user.isApproved) {
                cbIsAdmin.visibility = View.GONE // Hide admin toggle for unapproved users
            }
        }

        val dialog = AlertDialog.Builder(this)
            .setTitle(if (user == null) "Add User" else if (user.isApproved) "Edit User" else "Approve User")
            .setView(view)
            .setPositiveButton(if (user != null && !user.isApproved) "Approve & Save" else "Save", null)
            .setNegativeButton("Cancel", null)
            .create()

        dialog.setOnShowListener {
            val saveBtn = dialog.getButton(AlertDialog.BUTTON_POSITIVE)
            saveBtn.setOnClickListener {
                val name = editName.text.toString()
                val email = editEmail.text.toString()
                val pass = editPass.text.toString()
                val pos = editPos.text.toString()
                val isAdmin = cbIsAdmin.isChecked

                if (user == null) {
                    if (email.isNotEmpty() && pass.isNotEmpty()) {
                        createUser(name, email, pass, pos, isAdmin)
                        dialog.dismiss()
                    } else {
                        Toast.makeText(this, "Email and Password required", Toast.LENGTH_SHORT).show()
                    }
                } else {
                    val updatedUser = user.copy(name = name, position = pos, isAdmin = isAdmin, isApproved = true)
                    usersRef.child(user.id).setValue(updatedUser)
                        .addOnSuccessListener {
                            // Send congratulations email
                            resetUserPassword(user.email)
                            Toast.makeText(this, "User approved and email sent", Toast.LENGTH_SHORT).show()
                            
                            // Send a personal notification to the user
                            val congratsNotif = com.aurex.scanner.data.Notification(
                                title = "Account Approved!",
                                message = "Congratulations! Your account has been approved. You can now access all features.",
                                type = "info"
                            )
                            com.aurex.scanner.util.NotificationHelper.sendNotification(user.id, congratsNotif)
                        }
                    dialog.dismiss()
                }
            }
        }

        if (user != null) {
            dialog.setButton(AlertDialog.BUTTON_NEUTRAL, "Reset Password") { _, _ ->
                resetUserPassword(user.email)
            }
        }

        dialog.show()
    }

    private fun resetUserPassword(email: String) {
        FirebaseAuth.getInstance().sendPasswordResetEmail(email)
            .addOnSuccessListener {
                Toast.makeText(this, "Reset email sent to $email", Toast.LENGTH_SHORT).show()
            }
            .addOnFailureListener { e ->
                Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
            }
    }

    private fun createUser(name: String, email: String, pass: String, position: String, isAdmin: Boolean) {
        // Create user in Firebase Auth
        FirebaseAuth.getInstance().createUserWithEmailAndPassword(email, pass)
            .addOnSuccessListener { result ->
                val userId = result.user?.uid ?: return@addOnSuccessListener
                val newUser = User(id = userId, name = name, email = email, position = position, isAdmin = isAdmin)
                usersRef.child(userId).setValue(newUser)
                Toast.makeText(this, "User created successfully", Toast.LENGTH_SHORT).show()
            }
            .addOnFailureListener {
                Toast.makeText(this, "Failed: ${it.message}", Toast.LENGTH_SHORT).show()
            }
    }

    private fun confirmDeleteUser(user: User) {
        AlertDialog.Builder(this)
            .setTitle("Delete User")
            .setMessage("Delete ${user.name}?")
            .setPositiveButton("Delete") { _, _ ->
                usersRef.child(user.id).removeValue()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun loadDashboardData() {
        val db = AppDatabase.getDatabase(this)
        lifecycleScope.launch(Dispatchers.IO) {
            // Load local data first for immediate display
            allAdminProducts = db.productDao().getAllList()
            updateDashboardUI()

            // Fetch remote data from all users in RTDB
            val usersRef = FirebaseUtils.getDatabase().getReference("users")
            usersRef.addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    lifecycleScope.launch(Dispatchers.Default) {
                        val remoteProducts = mutableListOf<Product>()
                        for (userSnapshot in snapshot.children) {
                            val productsSnapshot = userSnapshot.child("products")
                            if (productsSnapshot.exists()) {
                                for (productSnapshot in productsSnapshot.children) {
                                    try {
                                        val product = productSnapshot.getValue(Product::class.java)
                                        if (product != null) {
                                            if (product.productCode.isEmpty()) product.productCode = productSnapshot.key ?: ""
                                            product.isSynced = true
                                            remoteProducts.add(product)
                                        }
                                    } catch (e: Exception) {
                                        android.util.Log.e("AdminActivity", "Error parsing product", e)
                                    }
                                }
                            }
                        }
                        
                        if (remoteProducts.isNotEmpty()) {
                            allAdminProducts = remoteProducts
                            withContext(Dispatchers.Main) {
                                updateDashboardUI()
                                swipeRefresh.isRefreshing = false
                            }
                        } else {
                            withContext(Dispatchers.Main) {
                                updateDashboardUI() // Still update to show local if no remote
                                swipeRefresh.isRefreshing = false
                            }
                        }
                    }
                }

                override fun onCancelled(error: DatabaseError) {
                    swipeRefresh.isRefreshing = false
                }
            })
        }
    }

    private suspend fun updateDashboardUI() {
        val expiredCount = allAdminProducts.count { TextParser.isExpired(it.expDate) }
        val nearExpiryCount = allAdminProducts.count { TextParser.isNearExpiry(it.expDate) }
        
        withContext(Dispatchers.Main) {
            txtTotal.text = allAdminProducts.size.toString()
            txtExpired.text = expiredCount.toString()
            txtNearExpiry.text = nearExpiryCount.toString()
            updateFilteredList()
            updatePremiumCharts()
        }
    }

    private fun toggleAnalytics() {
        if (layoutAnalyticsContent.visibility == View.GONE) {
            layoutAnalyticsContent.visibility = View.VISIBLE
            imgExpandAnalytics.animate().rotation(180f).setDuration(300).start()
            layoutAnalyticsContent.alpha = 0f
            layoutAnalyticsContent.animate().alpha(1f).setDuration(400).start()
        } else {
            layoutAnalyticsContent.animate().alpha(0f).setDuration(300).withEndAction {
                layoutAnalyticsContent.visibility = View.GONE
            }.start()
            imgExpandAnalytics.animate().rotation(0f).setDuration(300).start()
        }
    }

    private fun updatePremiumCharts() {
        chartDonutStatus.removeAllViews()
        chartPieCategory.removeAllViews()
        chartCircleWarehouse.removeAllViews()

        if (allAdminProducts.isEmpty()) return

        // 1. Status Donut (Interactive: Click slices to filter list)
        val expired = allAdminProducts.count { TextParser.isExpired(it.expDate) }.toFloat()
        val near = allAdminProducts.count { TextParser.isNearExpiry(it.expDate) }.toFloat()
        val good = (allAdminProducts.size - expired - near)
        
        val statusData = listOf(
            ChartSlice(getString(R.string.expired), expired, Color.parseColor("#FF5252"), "expired"),
            ChartSlice(getString(R.string.near), near, Color.parseColor("#FFAB40"), "near_expiry"),
            ChartSlice(getString(R.string.healthy), good, Color.parseColor("#69F0AE"), "all")
        )
        chartDonutStatus.addView(PremiumChartView(this, statusData, isDonut = true) { filter ->
            currentFilter = filter
            updateFilteredList()
        })

        // 2. Category Pie (Measure: Product count per category)
        val catMap = allAdminProducts.groupBy { it.category ?: getString(R.string.general) }
        val catGroups = if (catMap.isEmpty() && allAdminProducts.isNotEmpty()) mapOf(getString(R.string.general) to emptyList<Product>()) else catMap
        val catColors = listOf("#7C4DFF", "#448AFF", "#00BCD4", "#00E676", "#FFEB3B", "#FF5252")
        val catData = catGroups.entries.sortedByDescending { it.value.size }.take(5).mapIndexed { index, entry ->
            ChartSlice(entry.key, entry.value.size.toFloat(), Color.parseColor(catColors[index % catColors.size]), entry.key)
        }
        chartPieCategory.addView(PremiumChartView(this, catData, isDonut = false) { cat ->
            // Filter list by category if needed
        })

        // 3. Warehouse Circle (Measure: Space/Item distribution)
        val whGroups = allAdminProducts.groupBy { it.warehouseName ?: getString(R.string.main_warehouse) }
        val whColors = listOf("#FF4081", "#E040FB", "#7C4DFF", "#536DFE", "#448AFF")
        val whData = whGroups.entries.mapIndexed { index, entry ->
            ChartSlice(entry.key, entry.value.size.toFloat(), Color.parseColor(whColors[index % whColors.size]), entry.key)
        }
        chartCircleWarehouse.addView(PremiumChartView(this, whData, isDonut = false) { wh ->
            // Filter list by warehouse
        })
    }

    data class ChartSlice(val label: String, val value: Float, val color: Int, val tag: String)

    class PremiumChartView(
        context: android.content.Context,
        private val data: List<ChartSlice>,
        private val isDonut: Boolean,
        private val onClick: (String) -> Unit
    ) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val rect = RectF()
        private val total = data.sumOf { it.value.toDouble() }.toFloat()

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val size = Math.min(width, height).toFloat()
            val pad = size * 0.1f
            rect.set(pad, pad, size - pad, size - pad)

            if (total == 0f) return

            var startAngle = -90f
            data.forEach { slice ->
                val sweep = (slice.value / total) * 360f
                paint.color = slice.color
                paint.style = Paint.Style.FILL
                
                // Add a subtle shadow/glow effect
                paint.setShadowLayer(10f, 0f, 0f, slice.color and 0x80FFFFFF.toInt())
                canvas.drawArc(rect, startAngle, sweep, true, paint)
                paint.clearShadowLayer()
                
                startAngle += sweep
            }

            if (isDonut) {
                paint.color = Color.parseColor("#F5F5F5") // Center color
                canvas.drawCircle(size / 2, size / 2, size * 0.25f, paint)
                
                paint.color = Color.DKGRAY
                paint.textAlign = Paint.Align.CENTER
                paint.textSize = size * 0.12f
                paint.typeface = Typeface.DEFAULT_BOLD
                canvas.drawText(total.toInt().toString(), size / 2, size / 2 + (paint.textSize / 3), paint)
            }
        }
        
        override fun onTouchEvent(event: android.view.MotionEvent): Boolean {
            if (event.action == android.view.MotionEvent.ACTION_UP) {
                performClick()
                onClick(data.firstOrNull()?.tag ?: "all")
                return true
            }
            return true
        }

        override fun performClick(): Boolean {
            super.performClick()
            return true
        }
    }

    private fun confirmDeleteProduct(product: Product) {
        AlertDialog.Builder(this)
            .setTitle("Delete Product")
            .setMessage("Are you sure you want to delete ${product.name}?")
            .setPositiveButton("Delete") { _, _ ->
                lifecycleScope.launch(Dispatchers.IO) {
                    AppDatabase.getDatabase(this@AdminActivity).productDao().delete(product)
                    loadDashboardData()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }
}
