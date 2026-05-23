package com.aurex.scanner.ui

import android.content.Intent
import android.graphics.*
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.appcompat.app.AlertDialog
import androidx.lifecycle.lifecycleScope
import com.aurex.scanner.R
import com.aurex.scanner.data.AppDatabase
import com.aurex.scanner.data.Product
import com.bumptech.glide.Glide
import com.github.chrisbanes.photoview.PhotoView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.Transaction
import com.google.firebase.database.MutableData
import com.google.firebase.database.DatabaseError
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import androidx.camera.core.ExperimentalGetImage

@ExperimentalGetImage
class ResultActivity : BaseActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_result)

        val product = intent.getSerializableExtra("data") as? Product ?: return
        val viewOnly = intent.getBooleanExtra("VIEW_ONLY", false)

        val imgPreview = findViewById<ImageView>(R.id.imgProductPreview)
        val imgEditPreview = findViewById<ImageView>(R.id.imgEditPreview)
        
        // View Mode views
        val layoutViewMode = findViewById<LinearLayout>(R.id.layoutViewMode)
        val txtProductCodeView = findViewById<TextView>(R.id.txtProductCodeView)
        val txtNameView = findViewById<TextView>(R.id.txtNameView)
        val txtMfgDisplayView = findViewById<TextView>(R.id.txtMfgDisplayView)
        val txtExpDisplayView = findViewById<TextView>(R.id.txtExpDisplayView)
        val txtCategoryView = findViewById<TextView>(R.id.txtCategoryView)
        val txtWarehouseView = findViewById<TextView>(R.id.txtWarehouseView)
        val txtQuantityView = findViewById<TextView>(R.id.txtQuantityView)
        val txtSizeView = findViewById<TextView>(R.id.txtSizeView)

        // Edit Mode views
        val layoutEditMode = findViewById<LinearLayout>(R.id.layoutEditMode)
        val editProductCode = findViewById<EditText>(R.id.editProductCode)
        val editName = findViewById<EditText>(R.id.editName)
        val editQuantity = findViewById<EditText>(R.id.editQuantity)
        val editSize = findViewById<EditText>(R.id.editSize)
        val editCategory = findViewById<AutoCompleteTextView>(R.id.editCategory)
        val editWarehouse = findViewById<EditText>(R.id.editWarehouse)
        val editMfg = findViewById<EditText>(R.id.editMfg)
        val editExp = findViewById<EditText>(R.id.editExp)
        val btnSave = findViewById<Button>(R.id.btnSave)
        val btnRescan = findViewById<Button>(R.id.btnRescan)
        val tilProductCode = findViewById<com.google.android.material.textfield.TextInputLayout>(R.id.tilProductCode)

        fun updateUI(p: Product) {
            val notFound = getString(R.string.not_found)
            val general = getString(R.string.general)
            val na = getString(R.string.na)

            // View Mode
            txtProductCodeView.text = p.productCode
            txtNameView.text = p.name
            txtMfgDisplayView.text = getString(R.string.mfg_label, p.mfgDate ?: notFound)
            txtExpDisplayView.text = getString(R.string.exp_label, p.expDate ?: notFound)
            txtCategoryView.text = p.category ?: general
            txtWarehouseView.text = p.warehouseName ?: na
            txtQuantityView.text = p.quantity
            txtSizeView.text = p.size ?: na

            // Edit Mode
            editProductCode.setText(p.productCode)
            editName.setText(p.name)
            editQuantity.setText(p.quantity)
            editSize.setText(p.size ?: "")
            editCategory.setText(p.category ?: general)
            editWarehouse.setText(p.warehouseName ?: getSharedPreferences("AurexPrefs", MODE_PRIVATE).getString("lastWarehouse", ""))
            editMfg.setText(p.mfgDate ?: "")
            editExp.setText(p.expDate ?: "")
        }

        updateUI(product)

        val toolbar = findViewById<androidx.appcompat.widget.Toolbar>(R.id.toolbar)
        setSupportActionBar(toolbar)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.setHomeAsUpIndicator(android.R.drawable.ic_menu_today)

        if (viewOnly) {
            layoutViewMode.visibility = View.VISIBLE
            layoutEditMode.visibility = View.GONE
            btnSave.visibility = View.GONE
            btnRescan.text = getString(R.string.edit)
            
            btnRescan.setOnClickListener {
                if (btnRescan.text == getString(R.string.edit)) {
                    layoutViewMode.visibility = View.GONE
                    layoutEditMode.visibility = View.VISIBLE
                    btnSave.visibility = View.VISIBLE
                    btnRescan.text = getString(R.string.cancel)
                } else {
                    layoutViewMode.visibility = View.VISIBLE
                    layoutEditMode.visibility = View.GONE
                    btnSave.visibility = View.GONE
                    btnRescan.text = getString(R.string.edit)
                }
            }
        } else {
            layoutViewMode.visibility = View.GONE
            layoutEditMode.visibility = View.VISIBLE
            btnSave.visibility = View.VISIBLE
            btnSave.text = getString(R.string.save_to_history)
            btnRescan.text = getString(R.string.re_scan)
            btnRescan.setOnClickListener { finish() }
        }

        tilProductCode.setEndIconOnClickListener {
            val intent = Intent(this, BarcodeScannerActivity::class.java)
            startActivityForResult(intent, 1001)
        }

        findViewById<com.google.android.material.textfield.TextInputLayout>(R.id.tilProductName).setEndIconOnClickListener {
            val intent = Intent(this, ScannerActivity::class.java)
            intent.putExtra("SINGLE_SCAN_MODE", true)
            intent.putExtra("SCAN_TARGET", "NAME")
            startActivityForResult(intent, 1002)
        }

        findViewById<com.google.android.material.textfield.TextInputLayout>(R.id.tilMfg).setEndIconOnClickListener {
            val intent = Intent(this, ScannerActivity::class.java)
            intent.putExtra("SINGLE_SCAN_MODE", true)
            intent.putExtra("SCAN_TARGET", "MFG")
            startActivityForResult(intent, 1003)
        }

        findViewById<com.google.android.material.textfield.TextInputLayout>(R.id.tilExp).setEndIconOnClickListener {
            val intent = Intent(this, ScannerActivity::class.java)
            intent.putExtra("SINGLE_SCAN_MODE", true)
            intent.putExtra("SCAN_TARGET", "EXP")
            startActivityForResult(intent, 1004)
        }

        setupCategoryDropdown(editCategory)

        product.imagePath?.let { path ->
            val targetImages = listOf(imgPreview, imgEditPreview)
            
            Glide.with(this)
                .asBitmap()
                .load(path)
                .into(object : com.bumptech.glide.request.target.CustomTarget<Bitmap>() {
                    override fun onResourceReady(resource: Bitmap, transition: com.bumptech.glide.request.transition.Transition<in Bitmap>?) {
                        val highlighted = highlightDatesOnBitmap(resource, product)
                        targetImages.forEach { it.setImageBitmap(highlighted) }
                    }
                    override fun onLoadCleared(placeholder: android.graphics.drawable.Drawable?) {}
                })
            
            val zoomListener = View.OnClickListener { showImageZoomDialog(product) }
            imgPreview.setOnClickListener(zoomListener)
            imgEditPreview.setOnClickListener(zoomListener)
        }

        btnSave.setOnClickListener {
            val updatedCode = editProductCode.text.toString().trim()
            val updatedName = editName.text.toString().trim()
            val qtyString = editQuantity.text.toString().trim()
            val sizeString = editSize.text.toString().trim()
            val categoryString = editCategory.text.toString().trim()
            val warehouseString = editWarehouse.text.toString().trim()
            val mfgString = editMfg.text.toString().trim()
            val expString = editExp.text.toString().trim()
            
            if (updatedCode.isEmpty()) {
                Toast.makeText(this, "Please enter a product code", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            if (updatedName.isEmpty()) {
                Toast.makeText(this, "Please enter a product name", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            getSharedPreferences("AurexPrefs", MODE_PRIVATE).edit()
                .putString("lastWarehouse", warehouseString)
                .apply()

            val finalProduct = product.copy(
                productCode = updatedCode,
                name = updatedName,
                mfgDate = if (mfgString.isEmpty()) null else mfgString,
                expDate = if (expString.isEmpty()) null else expString,
                quantity = qtyString,
                size = sizeString,
                category = if (categoryString.isEmpty()) "General" else categoryString,
                warehouseName = warehouseString,
                isSynced = false
            )
            checkDuplicateAndSave(finalProduct)
        }
    }

    override fun onCreateOptionsMenu(menu: android.view.Menu): Boolean {
        menuInflater.inflate(R.menu.top_menu, menu)
        menu.findItem(R.id.action_home)?.isVisible = false
        return true
    }

    override fun onOptionsItemSelected(item: android.view.MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                val intent = android.content.Intent(this, MainActivity::class.java)
                intent.flags = android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP or android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
                startActivity(intent)
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode == RESULT_OK) {
            val scannedResult = data?.getStringExtra("SCAN_RESULT")
            if (scannedResult != null) {
                when (requestCode) {
                    1001 -> {
                        findViewById<EditText>(R.id.editProductCode).setText(scannedResult)
                        Toast.makeText(this, "Barcode Scanned: $scannedResult", Toast.LENGTH_SHORT).show()
                    }
                    1002 -> {
                        findViewById<EditText>(R.id.editName).setText(scannedResult)
                        Toast.makeText(this, "Product Name Scanned: $scannedResult", Toast.LENGTH_SHORT).show()
                    }
                    1003 -> {
                        findViewById<EditText>(R.id.editMfg).setText(scannedResult)
                        Toast.makeText(this, "MFG Date Scanned: $scannedResult", Toast.LENGTH_SHORT).show()
                    }
                    1004 -> {
                        findViewById<EditText>(R.id.editExp).setText(scannedResult)
                        Toast.makeText(this, "EXP Date Scanned: $scannedResult", Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }
    }

    private fun setupCategoryDropdown(autoCompleteTextView: AutoCompleteTextView) {
        val db = AppDatabase.getDatabase(this)
        lifecycleScope.launch {
            val categories = db.productDao().getAllCategories().toMutableList()
            if (!categories.contains("General")) {
                categories.add(0, "General")
            }
            
            val adapter = ArrayAdapter(
                this@ResultActivity,
                android.R.layout.simple_dropdown_item_1line,
                categories
            )
            autoCompleteTextView.setAdapter(adapter)
            
            // Allow showing all suggestions when clicked, even if text is entered
            autoCompleteTextView.setOnClickListener {
                autoCompleteTextView.showDropDown()
            }
            
            // Ensure dropdown opens when focused
            autoCompleteTextView.setOnFocusChangeListener { _, hasFocus ->
                if (hasFocus && autoCompleteTextView.text.isEmpty()) {
                    autoCompleteTextView.showDropDown()
                }
            }
        }
    }

    private fun checkDuplicateAndSave(product: Product) {
        val db = AppDatabase.getDatabase(this)
        val isViewOnly = intent.getBooleanExtra("VIEW_ONLY", false)
        lifecycleScope.launch {
            val existing = product.productCode.let { db.productDao().getByProductCode(it) }
            if (existing != null && !isViewOnly) {
                withContext(Dispatchers.Main) {
                    AlertDialog.Builder(this@ResultActivity)
                        .setTitle(getString(R.string.duplicate_product_code))
                        .setMessage(getString(R.string.duplicate_msg))
                        .setPositiveButton(getString(R.string.update_existing)) { _, _ ->
                            val updatedProduct = existing.copy(
                                name = product.name,
                                mfgDate = product.mfgDate,
                                expDate = product.expDate,
                                quantity = product.quantity,
                                size = product.size,
                                category = product.category,
                                warehouseName = product.warehouseName,
                                imagePath = product.imagePath,
                                barcode = product.barcode
                            )
                            updateAndFinish(updatedProduct)
                        }
                        .setNegativeButton(getString(R.string.discard)) { _, _ ->
                            finish()
                        }
                        .show()
                }
            } else if (isViewOnly) {
                // If we are in view mode and editing, we just update it.
                // Note: product.productCode is the key.
                updateAndFinish(product)
            } else {
                saveAndFinish(product)
            }
        }
    }

    private fun updateAndFinish(product: Product) {
        val db = AppDatabase.getDatabase(this)
        lifecycleScope.launch {
            db.productDao().update(product)
            incrementDailyScanCount()
            checkExpiryAndNotify(product)
            withContext(Dispatchers.Main) {
                Toast.makeText(this@ResultActivity, getString(R.string.product_updated), Toast.LENGTH_SHORT).show()
                navigateToHistory()
            }
        }
    }

    private fun saveAndFinish(product: Product) {
        val db = AppDatabase.getDatabase(this)
        lifecycleScope.launch {
            db.productDao().insert(product)
            incrementDailyScanCount()
            checkExpiryAndNotify(product)
            withContext(Dispatchers.Main) {
                Toast.makeText(this@ResultActivity, getString(R.string.saved_to_history), Toast.LENGTH_SHORT).show()
                navigateToHistory()
            }
        }
    }

    private fun incrementDailyScanCount() {
        val userId = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
        val dailyActivityRef = FirebaseDatabase.getInstance(databaseUrl).getReference("users")
            .child(userId)
            .child("dailyActivity")
            .child(today)
            .child("scans")

        dailyActivityRef.runTransaction(object : Transaction.Handler {
            override fun doTransaction(mutableData: MutableData): Transaction.Result {
                val currentScans = mutableData.getValue(Int::class.java) ?: 0
                mutableData.setValue(currentScans + 1)
                return Transaction.success(mutableData)
            }

            override fun onComplete(error: DatabaseError?, committed: Boolean, currentData: com.google.firebase.database.DataSnapshot?) {
                if (error != null) {
                    android.util.Log.e("ResultActivity", "Firebase transaction failed: ${error.message}")
                }
            }
        })
    }

    private fun checkExpiryAndNotify(product: Product) {
        val expStr = product.expDate ?: return
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val formatter = java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy")
                val expiry = java.time.LocalDate.parse(expStr, formatter)
                val today = java.time.LocalDate.now()
                val daysLeft = java.time.temporal.ChronoUnit.DAYS.between(today, expiry)

                val alertDays = listOf(45L, 30L, 15L, 10L, 5L, 3L, 1L, 0L)
                
                if (daysLeft in alertDays || daysLeft < 0) {
                    val message = when {
                        daysLeft < 0 -> getString(R.string.expired_alert_msg, Math.abs(daysLeft))
                        daysLeft == 0L -> getString(R.string.expires_today_msg)
                        else -> getString(R.string.expires_in_msg, daysLeft)
                    }

                    // 1. Mobile Notification
                    com.aurex.scanner.util.NotificationHelper.showSystemNotification(
                        this@ResultActivity,
                        if (daysLeft <= 0) getString(R.string.expiry_alert_title, product.name) else getString(R.string.near_expiry_title, product.name),
                        message,
                        product.name.hashCode()
                    )

                    // 2. In-App Notification (Firebase)
                    val userId = com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid
                    if (userId != null) {
                        val inAppNotif = com.aurex.scanner.data.Notification(
                            title = if (daysLeft <= 0) getString(R.string.expiry_alert_title, product.name) else getString(R.string.near_expiry_title, product.name),
                            message = message,
                            timestamp = System.currentTimeMillis(),
                            type = "expiry_alert"
                        )
                        com.aurex.scanner.util.NotificationHelper.sendNotification(userId, inAppNotif)
                        
                        // Also show a system notification immediately
                        com.aurex.scanner.util.NotificationHelper.showSystemNotification(
                            this@ResultActivity,
                            if (daysLeft <= 0) getString(R.string.expiry_alert_title, product.name) else getString(R.string.near_expiry_title, product.name),
                            message
                        )
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun navigateToHistory() {
        val intent = Intent(this@ResultActivity, ProductListActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        finish()
    }

    private fun showImageZoomDialog(product: Product) {
        val path = product.imagePath ?: return
        val dialog = android.app.Dialog(this, android.R.style.Theme_Black_NoTitleBar_Fullscreen)
        val photoView = PhotoView(this)
        photoView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        dialog.setContentView(photoView)

        Glide.with(this)
            .asBitmap()
            .load(path)
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

    private fun highlightDatesOnBitmap(original: Bitmap, product: Product): Bitmap {
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
}
