package com.aurex.scanner.util

import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreSettings

object FirebaseUtils {
    const val DATABASE_URL = "https://aurexscannerapp-default-rtdb.firebaseio.com"

    fun getDatabase(): FirebaseDatabase {
        val db = FirebaseDatabase.getInstance(DATABASE_URL)
        // Ensure persistence is set once if needed, but it's usually done in Application class
        return db
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
}
