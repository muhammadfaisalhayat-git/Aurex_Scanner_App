package com.aurex.scanner.ui

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import com.aurex.scanner.data.User
import com.aurex.scanner.util.FirebaseUtils
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.ValueEventListener

class SplashActivity : BaseActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(com.aurex.scanner.R.layout.activity_splash)

        Handler(Looper.getMainLooper()).postDelayed({
            checkAuthStatus()
        }, 2000)
    }

    private fun checkAuthStatus() {
        val auth = FirebaseAuth.getInstance()
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        val currentUser = auth.currentUser

        if (currentUser != null && prefs.getBoolean("rememberMe", false)) {
            val email = currentUser.email?.lowercase()?.trim() ?: ""
            
            // Admin bypass for speed
            if (email == "admin@aurex.com") {
                startMainActivity()
                return
            }

            // Verify approval status from server
            FirebaseUtils.getDatabase().getReference("users").child(currentUser.uid)
                .addListenerForSingleValueEvent(object : ValueEventListener {
                    override fun onDataChange(snapshot: DataSnapshot) {
                        val user = snapshot.getValue(User::class.java)
                        if (user?.isApproved == true) {
                            // Update admin status session just in case
                            prefs.edit().putBoolean("isAdmin", user.isAdmin).apply()
                            startMainActivity()
                        } else {
                            // User revoked or not approved
                            auth.signOut()
                            prefs.edit().putBoolean("rememberMe", false).apply()
                            Toast.makeText(this@SplashActivity, "Access denied: Account pending approval", Toast.LENGTH_LONG).show()
                            startLoginActivity()
                        }
                    }

                    override fun onCancelled(error: DatabaseError) {
                        // On network error, trust local session but show warning
                        startMainActivity()
                    }
                })
        } else {
            startLoginActivity()
        }
    }

    private fun startMainActivity() {
        startActivity(Intent(this, MainActivity::class.java))
        finish()
    }

    private fun startLoginActivity() {
        startActivity(Intent(this, LoginActivity::class.java))
        finish()
    }
}
