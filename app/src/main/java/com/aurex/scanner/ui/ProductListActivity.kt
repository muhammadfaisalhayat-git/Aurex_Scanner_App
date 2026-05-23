package com.aurex.scanner.ui

import android.graphics.*
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.EditText
import android.widget.ImageView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import java.io.File
import com.aurex.scanner.ProductAdapter
import com.aurex.scanner.R
import com.aurex.scanner.data.AppDatabase
import com.aurex.scanner.data.Product
import com.aurex.scanner.scanner.TextParser
import com.bumptech.glide.Glide
import com.github.chrisbanes.photoview.PhotoView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import android.view.Menu
import android.view.MenuItem
import androidx.appcompat.widget.Toolbar
import android.view.View
import androidx.camera.core.ExperimentalGetImage

@ExperimentalGetImage
class ProductListActivity : BaseActivity() {

    private lateinit var recyclerView: RecyclerView
    private lateinit var editSearch: EditText
    private var currentSort = "id"
    private var searchQuery: String? = null
    private var activeCodeEditText: EditText? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_product_list)

        recyclerView = findViewById(R.id.recyclerView)
        recyclerView.layoutManager = LinearLayoutManager(this)

        editSearch = findViewById(R.id.editSearch)
        findViewById<android.widget.ImageButton>(R.id.btnBack).setOnClickListener {
            onBackPressed()
        }

        findViewById<android.widget.ImageButton>(R.id.btnNotifications).setOnClickListener {
            showNotificationsDialog()
        }

        searchQuery = intent.getStringExtra("SEARCH_QUERY")
        if (!searchQuery.isNullOrBlank()) {
            editSearch.setText(searchQuery)
        }

        val btnClear = findViewById<android.widget.ImageButton>(R.id.btnClearSearch)
        btnClear.setOnClickListener {
            editSearch.setText("")
        }

        editSearch.addTextChangedListener(object : android.text.TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                searchQuery = s?.toString()
                btnClear.visibility = if (searchQuery.isNullOrBlank()) View.GONE else View.VISIBLE
                loadProducts()
            }
            override fun afterTextChanged(s: android.text.Editable?) {}
        })

        val filterType = intent.getStringExtra("FILTER_TYPE")
        if (filterType == "near_expiry") {
            currentSort = "near_expiry"
        }

        findViewById<com.google.android.material.chip.Chip>(R.id.chipCategory).setOnClickListener {
            showFilterDialog("category")
        }
        findViewById<com.google.android.material.chip.Chip>(R.id.chipWarehouse).setOnClickListener {
            showFilterDialog("warehouse")
        }
        findViewById<com.google.android.material.chip.Chip>(R.id.chipExpiry).setOnClickListener {
            currentSort = "expiry"
            loadProducts()
        }

        loadProducts()
    }

    private fun showFilterDialog(type: String) {
        val db = AppDatabase.getDatabase(this)
        lifecycleScope.launch(Dispatchers.IO) {
            val items = if (type == "category") {
                db.productDao().getAllCategories()
            } else {
                db.productDao().getAllList().mapNotNull { it.warehouseName }.distinct()
            }.toTypedArray()

            withContext(Dispatchers.Main) {
                AlertDialog.Builder(this@ProductListActivity)
                    .setTitle("Select $type")
                    .setItems(items) { _, which ->
                        currentSort = "${type}_${items[which]}"
                        loadProducts()
                    }
                    .setNeutralButton("Clear Filter") { _, _ ->
                        currentSort = "id"
                        loadProducts()
                    }
                    .show()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        loadProducts()
    }

    private fun loadProducts() {
        val db = AppDatabase.getDatabase(this)
        lifecycleScope.launch(Dispatchers.IO) {
            var allData = db.productDao().getAllList()
            
            // Apply Search Filter (Enhanced for multiple fields and languages)
            val filteredData = if (!searchQuery.isNullOrBlank()) {
                val q = searchQuery!!.lowercase().trim()
                allData.filter { product ->
                    (product.name.lowercase().contains(q)) ||
                    (product.productCode.lowercase().contains(q)) ||
                    (product.category?.lowercase()?.contains(q) == true) ||
                    (product.expDate?.contains(q) == true) ||
                    (product.mfgDate?.contains(q) == true) ||
                    (product.warehouseName?.lowercase()?.contains(q) == true) ||
                    (product.size?.lowercase()?.contains(q) == true) ||
                    (product.quantity.contains(q))
                }
            } else {
                allData
            }

            val sortedData = when {
                currentSort.startsWith("category_") -> {
                    val filter = currentSort.removePrefix("category_")
                    filteredData.filter { it.category == filter }
                }
                currentSort.startsWith("warehouse_") -> {
                    val filter = currentSort.removePrefix("warehouse_")
                    filteredData.filter { it.warehouseName == filter }
                }
                currentSort == "expiry" -> filteredData.sortedBy { TextParser.convertToSortable(it.expDate ?: "99/99/9999") }
                currentSort == "near_expiry" -> filteredData.filter { TextParser.isNearExpiry(it.expDate) }
                else -> filteredData.sortedByDescending { it.id }
            }

            // After sorting/filtering, convert to list if needed
            val finalData = sortedData.toList()

            withContext(Dispatchers.Main) {
                recyclerView.adapter = ProductAdapter(
                    finalData,
                    onClick = { product -> showProductProfile(product) },
                    onEdit = { product -> showEditDialog(product) },
                    onDelete = { product -> showDeleteConfirm(product) },
                    onViewImage = { product -> showImageDialog(product) }
                )
            }
        }
    }

    private fun showProductProfile(product: Product) {
        val intent = android.content.Intent(this, ResultActivity::class.java)
        intent.putExtra("data", product)
        intent.putExtra("VIEW_ONLY", true) // Optional flag if you want to disable editing in profile view
        startActivity(intent)
    }

    private fun showEditDialog(product: Product) {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_edit_product, null)
        val editCode = dialogView.findViewById<EditText>(R.id.editProductCode)
        val btnScanBarcode = dialogView.findViewById<android.widget.ImageButton>(R.id.btnScanBarcode)
        val editName = dialogView.findViewById<EditText>(R.id.editName)
        val editMfg = dialogView.findViewById<EditText>(R.id.editMfg)
        val editExp = dialogView.findViewById<EditText>(R.id.editExp)
        val editQty = dialogView.findViewById<EditText>(R.id.editQuantity)
        val editSize = dialogView.findViewById<EditText>(R.id.editSize)
        val editCategory = dialogView.findViewById<EditText>(R.id.editCategory)
        val editWarehouse = dialogView.findViewById<EditText>(R.id.editWarehouse)
        val tilMfg = dialogView.findViewById<com.google.android.material.textfield.TextInputLayout>(R.id.tilMfg)
        val tilExp = dialogView.findViewById<com.google.android.material.textfield.TextInputLayout>(R.id.tilExp)

        editCode.setText(product.productCode)
        editName.setText(product.name)
        editMfg.setText(product.mfgDate)
        editExp.setText(product.expDate)
        editQty.setText(product.quantity)
        editSize.setText(product.size)
        editCategory.setText(product.category)
        editWarehouse.setText(product.warehouseName)

        btnScanBarcode.setOnClickListener {
            activeCodeEditText = editCode
            val intent = android.content.Intent(this, BarcodeScannerActivity::class.java)
            startActivityForResult(intent, 1001)
        }

        tilMfg.setEndIconOnClickListener {
            activeCodeEditText = editMfg
            val intent = android.content.Intent(this, ScannerActivity::class.java)
            intent.putExtra("SINGLE_SCAN_MODE", true)
            intent.putExtra("SCAN_TARGET", "MFG")
            startActivityForResult(intent, 1002)
        }

        tilExp.setEndIconOnClickListener {
            activeCodeEditText = editExp
            val intent = android.content.Intent(this, ScannerActivity::class.java)
            intent.putExtra("SINGLE_SCAN_MODE", true)
            intent.putExtra("SCAN_TARGET", "EXP")
            startActivityForResult(intent, 1002)
        }

        AlertDialog.Builder(this)
            .setTitle("Edit Product")
            .setView(dialogView)
            .setPositiveButton("Save") { _, _ ->
                product.productCode = editCode.text.toString()
                product.name = editName.text.toString()
                product.mfgDate = editMfg.text.toString()
                product.expDate = editExp.text.toString()
                product.quantity = editQty.text.toString()
                product.size = editSize.text.toString()
                product.category = editCategory.text.toString()
                product.warehouseName = editWarehouse.text.toString()
                product.isSynced = false
                updateProduct(product)
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if ((requestCode == 1001 || requestCode == 1002) && resultCode == RESULT_OK) {
            val scannedCode = data?.getStringExtra("SCAN_RESULT")
            if (scannedCode != null && activeCodeEditText != null) {
                activeCodeEditText?.setText(scannedCode)
                Toast.makeText(this, "Scanned: $scannedCode", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun updateProduct(product: Product) {
        val db = AppDatabase.getDatabase(this)
        lifecycleScope.launch(Dispatchers.IO) {
            db.productDao().update(product)
            withContext(Dispatchers.Main) {
                loadProducts()
                Toast.makeText(this@ProductListActivity, "Product updated", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun showDeleteConfirm(product: Product) {
        AlertDialog.Builder(this)
            .setTitle("Delete Product")
            .setMessage("Are you sure you want to delete ${product.name}?")
            .setPositiveButton("Delete") { _, _ ->
                val db = AppDatabase.getDatabase(this)
                lifecycleScope.launch(Dispatchers.IO) {
                    db.productDao().delete(product)
                    withContext(Dispatchers.Main) {
                        loadProducts()
                        Toast.makeText(this@ProductListActivity, "Product deleted", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showImageDialog(product: Product) {
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
                    Toast.makeText(this@ProductListActivity, "Failed to load image", Toast.LENGTH_SHORT).show()
                    dialog.dismiss()
                }
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
