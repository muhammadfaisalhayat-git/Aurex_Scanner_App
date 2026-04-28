package com.aurex.scanner

import android.app.Application
import com.aurex.scanner.scanner.OCRProcessor

class AurexApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
        try {
            val database = com.google.firebase.database.FirebaseDatabase.getInstance(databaseUrl)
            database.setPersistenceEnabled(true)
        } catch (e: Exception) {
            // Persistence might already be set
        }
        OCRProcessor.init(this)
    }
}
