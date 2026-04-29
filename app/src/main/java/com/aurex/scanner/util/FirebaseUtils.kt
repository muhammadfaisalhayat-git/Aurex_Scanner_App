package com.aurex.scanner.util

import android.content.Context
import android.widget.Toast
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

object FirebaseUtils {
    const val DATABASE_URL = "https://aurexscannerapp-default-rtdb.firebaseio.com"

    fun getDatabase(): FirebaseDatabase {
        return FirebaseDatabase.getInstance()
    }

    fun getFirestore(): FirebaseFirestore {
        val firestore = FirebaseFirestore.getInstance()
        // Optional: Configure settings if needed
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

        val productsToUpload = allProducts.filter { !it.isSynced }

        if (productsToUpload.isEmpty()) {
            withContext(Dispatchers.Main) {
                onProgress?.invoke(0, 0, "Up to date")
                androidx.appcompat.app.AlertDialog.Builder(context)
                    .setTitle("Cloud Backup")
                    .setMessage("The Product list is up to date with server.")
                    .setPositiveButton("OK", null)
                    .show()
            }
            return
        }

        val total = productsToUpload.size
        var current = 0
        try {
            val rtdb = getDatabase()
            rtdb.goOnline()
            
            val userRef = rtdb.getReference("users").child(user.uid).child("products")
            
            withContext(Dispatchers.Main) {
                onProgress?.invoke(0, total, "Preparing backup...")
                NotificationHelper.showProgressNotification(context, "Cloud Backup", "Starting backup...", 0, total, true)
            }

            for (product in productsToUpload) {
                val code = if (product.productCode.isBlank()) {
                    "TEMP_${System.currentTimeMillis()}_${product.id}"
                } else {
                    product.productCode.replace(".", "_")
                        .replace("#", "_")
                        .replace("$", "_")
                        .replace("[", "_")
                        .replace("]", "_")
                }

                // Upload individual product
                userRef.child(code).setValue(product).await()
                
                current++
                withContext(Dispatchers.Main) {
                    onProgress?.invoke(current, total, product.name)
                    NotificationHelper.showProgressNotification(
                        context, 
                        "Cloud Backup", 
                        "Backing up: ${product.name} ($current/$total)", 
                        current, 
                        total, 
                        false
                    )
                }

                // Mark as synced locally
                withContext(Dispatchers.IO) {
                    product.isSynced = true
                    db.productDao().update(product)
                }
            }
            
            withContext(Dispatchers.Main) {
                onProgress?.invoke(total, total, "Sync complete!")
                NotificationHelper.showSystemNotification(context, "Cloud Backup", "Successfully backed up $total products.")
                NotificationHelper.cancelNotification(context)
                Toast.makeText(context, "Backup successful!", Toast.LENGTH_SHORT).show()
            }
        } catch (e: Exception) {
            withContext(Dispatchers.Main) {
                NotificationHelper.cancelNotification(context)
                val errorMsg = when (e) {
                    is kotlinx.coroutines.TimeoutCancellationException -> "Connection timed out. Please check your internet signal and try again."
                    else -> e.message ?: e.toString()
                }
                androidx.appcompat.app.AlertDialog.Builder(context)
                    .setTitle("Backup Failed")
                    .setMessage(errorMsg)
                    .setPositiveButton("OK", null)
                    .show()
            }
        }
    }

    suspend fun restoreFromRTDB(context: Context, onProgress: ((Int, Int, String) -> Unit)? = null) {
        val user = FirebaseAuth.getInstance().currentUser ?: return
        val rtdb = getDatabase()
        rtdb.goOnline()
        
        val userRef = rtdb.getReference("users").child(user.uid).child("products")

        try {
            withContext(Dispatchers.Main) {
                onProgress?.invoke(0, 0, "Connecting to cloud...")
                NotificationHelper.showProgressNotification(context, "Cloud Restore", "Connecting...", 0, 0, true)
            }

            // Perform fetch with an extended timeout (60 seconds)
            val snapshot = withTimeout(60000L) {
                userRef.get().await()
            }

            if (!snapshot.exists()) {
                withContext(Dispatchers.Main) {
                    NotificationHelper.cancelNotification(context)
                    Toast.makeText(context, "No backup found on server", Toast.LENGTH_SHORT).show()
                }
                return
            }

            val products = mutableListOf<Product>()
            val total = snapshot.childrenCount.toInt()
            var current = 0
            
            snapshot.children.forEach { child ->
                val product = child.getValue(Product::class.java)
                if (product != null) {
                    products.add(product)
                    current++
                    onProgress?.invoke(current, total, product.name)
                    NotificationHelper.showProgressNotification(
                        context, 
                        "Cloud Restore", 
                        "Downloading: ${product.name} ($current/$total)", 
                        current, 
                        total, 
                        false
                    )
                }
            }

            if (products.isNotEmpty()) {
                val localDb = AppDatabase.getDatabase(context)
                localDb.productDao().insertAll(products)
                withContext(Dispatchers.Main) {
                    NotificationHelper.showSystemNotification(context, "Cloud Restore", "Successfully restored ${products.size} products.")
                    NotificationHelper.cancelNotification(context)
                    Toast.makeText(context, "Restored ${products.size} products", Toast.LENGTH_SHORT).show()
                }
            }
        } catch (e: Exception) {
            withContext(Dispatchers.Main) {
                NotificationHelper.cancelNotification(context)
                Toast.makeText(context, "Restore failed: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
    }
}
