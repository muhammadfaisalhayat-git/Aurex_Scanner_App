package com.aurex.scanner.util

import android.content.Context
import android.widget.Toast
import com.aurex.scanner.R
import com.aurex.scanner.data.AppDatabase
import com.aurex.scanner.data.Product
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreSettings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import android.util.Log

import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit

object FirebaseUtils {
    private const val DATABASE_URL = "https://aurexscannerapp-default-rtdb.firebaseio.com"
    
    fun getDatabase(): FirebaseDatabase {
        val db = FirebaseDatabase.getInstance(DATABASE_URL)
        return db
    }

    fun getFirestore(): FirebaseFirestore {
        val firestore = FirebaseFirestore.getInstance()
        val settings = FirebaseFirestoreSettings.Builder()
            .setPersistenceEnabled(true)
            .build()
        firestore.firestoreSettings = settings
        return firestore
    }

    suspend fun backupToRTDB(context: Context, onProgress: ((Int, Int, String) -> Unit)? = null) {
        val user = FirebaseAuth.getInstance().currentUser ?: return
        val db = AppDatabase.getDatabase(context)
        val allProducts = db.productDao().getAllList()

        if (allProducts.isEmpty()) {
            withContext(Dispatchers.Main) {
                Toast.makeText(context, "No local products to backup.", Toast.LENGTH_SHORT).show()
            }
            return
        }

        val total = allProducts.size
        var completedCount = 0
        
        try {
            val rtdb = getDatabase()
            rtdb.goOnline()
            val userRef = rtdb.getReference("users").child(user.uid).child("products")
            
            withContext(Dispatchers.Main) {
                onProgress?.invoke(0, total, "Connecting to server...")
            }

            // Limit concurrency to avoid overloading network/Firebase
            val semaphore = Semaphore(5) 

            coroutineScope {
                allProducts.forEach { product ->
                    launch {
                        semaphore.withPermit {
                            try {
                                if (product.productCode.isBlank()) {
                                    product.productCode = "CODE_${System.currentTimeMillis()}_${product.id}"
                                }
                                
                                // Firebase RTDB keys cannot contain: . $ # [ ] /
                                val safeKey = product.productCode
                                        .replace(".", "_")
                                        .replace("#", "_")
                                        .replace("$", "_")
                                        .replace("[", "_")
                                        .replace("]", "_")
                                        .replace("/", "_")

                                // Mark as synced before uploading so the status is saved in cloud too
                                product.isSynced = true

                                withTimeout(30000L) {
                                    userRef.child(safeKey).setValue(product).await()
                                }

                                synchronized(this@FirebaseUtils) {
                                    completedCount++
                                }

                                withContext(Dispatchers.Main) {
                                    onProgress?.invoke(completedCount, total, product.name)
                                }

                                // Update local DB with synced status
                                withContext(Dispatchers.IO) {
                                    db.productDao().update(product)
                                }
                            } catch (e: Exception) {
                                Log.e("FirebaseUtils", "Failed to backup product: ${product.productCode}", e)
                            }
                        }
                    }
                }
            }
            
            withContext(Dispatchers.Main) {
                onProgress?.invoke(total, total, "Sync complete!")
                Toast.makeText(context, context.getString(R.string.success), Toast.LENGTH_SHORT).show()
            }
        } catch (e: Exception) {
            Log.e("FirebaseUtils", "Backup failed", e)
            withContext(Dispatchers.Main) {
                val errorMsg = when (e) {
                    is kotlinx.coroutines.TimeoutCancellationException -> context.getString(R.string.connection_timeout)
                    else -> e.message ?: context.getString(R.string.backup_failed)
                }
                androidx.appcompat.app.AlertDialog.Builder(context)
                    .setTitle(context.getString(R.string.backup_failed))
                    .setMessage(errorMsg)
                    .setPositiveButton(context.getString(R.string.ok), null)
                    .show()
            }
        }
    }

    suspend fun restoreFromRTDB(context: Context, onProgress: ((Int, Int, String) -> Unit)? = null) {
        val user = FirebaseAuth.getInstance().currentUser ?: return
        val rtdb = getDatabase()
        rtdb.goOnline()
        
        val userRef = rtdb.getReference("users").child(user.uid)
        val productsRef = userRef.child("products")

        try {
            withContext(Dispatchers.Main) {
                onProgress?.invoke(0, 0, "Connecting to server...")
                NotificationHelper.showProgressNotification(context, "Cloud Restore", "Connecting...", 0, 0, true)
            }

            // ROOT FIX: Try fetching the 'products' node directly first.
            // This is MUCH faster because it skips the heavy 'dailyActivity' logs.
            var snapshot = withTimeout(45000L) { 
                productsRef.get().await()
            }

            // If products folder is empty, fallback to the root node (legacy support)
            // but only if necessary, as this is the slow part.
            val products = mutableListOf<Product>()
            
            fun parseProduct(key: String, value: Any?): Product? {
                val map = value as? Map<*, *> ?: return null
                val name = (map["name"] as? String) ?: (map["productName"] as? String) ?: ""
                val code = (map["productCode"] as? String) ?: key
                
                if (name.isBlank() && (map["productCode"] as? String).isNullOrBlank()) return null
                
                return Product(
                    id = 0, // Room will auto-generate a new unique ID locally
                    productCode = code,
                    name = if (name.isBlank()) "Restored Product" else name,
                    mfgDate = (map["mfgDate"] as? String) ?: (map["mfg"] as? String),
                    expDate = (map["expDate"] as? String) ?: (map["exp"] as? String),
                    quantity = (map["quantity"] as? String) ?: "1",
                    size = (map["size"] as? String) ?: (map["weight"] as? String),
                    category = (map["category"] as? String) ?: "General",
                    imagePath = map["imagePath"] as? String,
                    warehouseName = map["warehouseName"] as? String,
                    barcode = map["barcode"] as? String,
                    mfgBox = map["mfgBox"] as? String,
                    expBox = map["expBox"] as? String,
                    isSynced = true,
                    groupId = (map["groupId"] as? String) ?: "lafi_al_harbi_group",
                    companyId = (map["companyId"] as? String) ?: "bin_awf"
                )
            }

            if (snapshot.exists()) {
                snapshot.children.forEach { child ->
                    parseProduct(child.key ?: "", child.value)?.let { products.add(it) }
                }
            } else {
                // Legacy Fallback: Only if 'products' node doesn't exist
                val rootSnapshot = withTimeout(45000L) { userRef.get().await() }
                val reservedKeys = listOf("products", "profile", "settings", "dailyActivity", "lastLogin", "token", "role")
                rootSnapshot.children.forEach { child ->
                    if (child.key !in reservedKeys) {
                        parseProduct(child.key ?: "", child.value)?.let { products.add(it) }
                    }
                }
            }

            if (products.isNotEmpty()) {
                val localDb = AppDatabase.getDatabase(context)
                withContext(Dispatchers.IO) {
                    // We clear the local database before a full restore to prevent 
                    // mixing old local IDs with server data.
                    localDb.productDao().deleteAll()
                    localDb.productDao().insertAll(products)
                }
                
                withContext(Dispatchers.Main) {
                    val totalCount = products.size
                    onProgress?.invoke(totalCount, totalCount, "Restored $totalCount items")
                    NotificationHelper.showSystemNotification(context, "Cloud Restore", "Successfully restored $totalCount products.")
                    NotificationHelper.cancelNotification(context)
                    androidx.appcompat.app.AlertDialog.Builder(context)
                        .setTitle("Success")
                        .setMessage("Successfully restored $totalCount products from cloud.")
                        .setPositiveButton("OK", null)
                        .show()
                }
            } else {
                withContext(Dispatchers.Main) {
                    NotificationHelper.cancelNotification(context)
                    androidx.appcompat.app.AlertDialog.Builder(context)
                        .setTitle("Restore")
                        .setMessage("No valid backup data was found on the server.")
                        .setPositiveButton("OK", null)
                        .show()
                }
            }
        } catch (e: Exception) {
            Log.e("FirebaseUtils", "Restore failed", e)
            withContext(Dispatchers.Main) {
                NotificationHelper.cancelNotification(context)
                val msg = if (e is kotlinx.coroutines.TimeoutCancellationException) 
                    "The connection is too slow. Please try moving to a better network area and try again."
                    else "Connection Error: ${e.message}"
                
                androidx.appcompat.app.AlertDialog.Builder(context)
                    .setTitle("Restore Failed")
                    .setMessage(msg)
                    .setPositiveButton("OK", null)
                    .show()
            }
        }
    }
}
