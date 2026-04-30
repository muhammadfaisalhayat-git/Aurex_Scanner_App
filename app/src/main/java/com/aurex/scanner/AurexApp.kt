package com.aurex.scanner

import android.app.Application
import com.aurex.scanner.scanner.OCRProcessor

class AurexApp : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            val database = com.google.firebase.database.FirebaseDatabase.getInstance()
            database.setPersistenceEnabled(true)
        } catch (e: Exception) {
            // Persistence might already be set
        }
        OCRProcessor.init(this)
    }
}
