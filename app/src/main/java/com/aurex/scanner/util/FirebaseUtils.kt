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
import android.util.Log

object FirebaseUtils {
    
    fun getDatabase(): FirebaseDatabase {
        val db = FirebaseDatabase.getInstance()
        // Persistence is already set in AurexApp.kt
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
            val userRef = rtdb.getReference("users").child(user.uid).child("products")
            
            withContext(Dispatchers.Main) {
                onProgress?.invoke(0, total, "Preparing backup...")
                NotificationHelper.showProgressNotification(context, "Cloud Backup", "Starting backup...", 0, total, true)
            }

            for (product in productsToUpload) {
                if (product.productCode.isBlank()) {
                    product.productCode = "CODE_${System.currentTimeMillis()}_${product.id}"
                }

                val code = product.productCode.replace(".", "_")
                        .replace("#", "_")
                        .replace("$", "_")
                        .replace("[", "_")
                        .replace("]", "_")

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
            Log.e("FirebaseUtils", "Backup failed", e)
            withContext(Dispatchers.Main) {
                NotificationHelper.cancelNotification(context)
                androidx.appcompat.app.AlertDialog.Builder(context)
                    .setTitle("Backup Failed")
                    .setMessage(e.message ?: "Unknown error")
                    .setPositiveButton("OK", null)
                    .show()
            }
        }
    }

    suspend fun restoreFromRTDB(context: Context, onProgress: ((Int, Int, String) -> Unit)? = null) {
        val user = FirebaseAuth.getInstance().currentUser ?: return
        val rtdb = getDatabase()
        val userRef = rtdb.getReference("users").child(user.uid).child("products")

        try {
            withContext(Dispatchers.Main) {
                onProgress?.invoke(0, 0, "Connecting to cloud...")
                NotificationHelper.showProgressNotification(context, "Cloud Restore", "Connecting to secure server...", 0, 0, true)
            }

            // Using .get().await() which is more reliable for single fetches
            // and respects local persistence better.
            val snapshot = withTimeout(60000L) { // 60 seconds is plenty for a good connection
                userRef.get().await()
            }

            if (!snapshot.exists()) {
                withContext(Dispatchers.Main) {
                    NotificationHelper.cancelNotification(context)
                    androidx.appcompat.app.AlertDialog.Builder(context)
                        .setTitle("Restore")
                        .setMessage("No backup data found for this account on the server.")
                        .setPositiveButton("OK", null)
                        .show()
                }
                return
            }

            val products = mutableListOf<Product>()
            val total = snapshot.childrenCount.toInt()
            var current = 0
            
            snapshot.children.forEach { child ->
                val product = child.getValue(Product::class.java)
                if (product != null) {
                    product.isSynced = true
                    if (product.productCode.isBlank()) {
                        product.productCode = child.key ?: "RESTORED_${System.currentTimeMillis()}_$current"
                    }
                    products.add(product)
                    current++
                    
                    withContext(Dispatchers.Main) {
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
            }

            if (products.isNotEmpty()) {
                val localDb = AppDatabase.getDatabase(context)
                withContext(Dispatchers.IO) {
                    localDb.productDao().insertAll(products)
                }
                
                withContext(Dispatchers.Main) {
                    NotificationHelper.showSystemNotification(context, "Cloud Restore", "Successfully restored ${products.size} products.")
                    NotificationHelper.cancelNotification(context)
                    androidx.appcompat.app.AlertDialog.Builder(context)
                        .setTitle("Success")
                        .setMessage("Successfully restored ${products.size} products from cloud.")
                        .setPositiveButton("OK", null)
                        .show()
                }
            } else {
                withContext(Dispatchers.Main) {
                    NotificationHelper.cancelNotification(context)
                    Toast.makeText(context, "Restore complete: No products found in backup.", Toast.LENGTH_SHORT).show()
                }
            }
        } catch (e: Exception) {
            Log.e("FirebaseUtils", "Restore failed", e)
            withContext(Dispatchers.Main) {
                NotificationHelper.cancelNotification(context)
                val errorMsg = when(e) {
                    is kotlinx.coroutines.TimeoutCancellationException -> 
                        "Connection timed out. The server is not responding. Please check your network and try again."
                    else -> e.message ?: "An unknown error occurred during restore."
                }
                androidx.appcompat.app.AlertDialog.Builder(context)
                    .setTitle("Restore Failed")
                    .setMessage(errorMsg)
                    .setPositiveButton("OK", null)
                    .show()
            }
        }
    }
}
