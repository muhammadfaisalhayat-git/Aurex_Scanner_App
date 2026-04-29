package com.aurex.scanner.ui

import android.os.Bundle
import android.view.View
import android.widget.EditText
import android.widget.RadioGroup
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatDelegate
import androidx.appcompat.widget.SwitchCompat
import androidx.lifecycle.lifecycleScope
import com.aurex.scanner.R
import com.aurex.scanner.util.FirebaseUtils
import com.google.android.material.button.MaterialButton
import com.google.firebase.auth.EmailAuthProvider
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import kotlinx.coroutines.launch

class SettingsActivity : BaseActivity() {

    private lateinit var auth: FirebaseAuth

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        auth = FirebaseAuth.getInstance()
        val user = auth.currentUser

        val txtCurrentEmail = findViewById<TextView>(R.id.txtCurrentEmail)
        val btnChangeEmail = findViewById<MaterialButton>(R.id.btnChangeEmail)
        val btnChangePassword = findViewById<MaterialButton>(R.id.btnChangePassword)

        txtCurrentEmail.text = user?.email ?: "Not logged in"

        btnChangeEmail.setOnClickListener {
            showReauthDialog {
                showUpdateEmailDialog()
            }
        }

        btnChangePassword.setOnClickListener {
            showReauthDialog {
                showUpdatePasswordDialog()
            }
        }

        val rgTheme = findViewById<RadioGroup>(R.id.rgTheme)
        val swBiometric = findViewById<SwitchCompat>(R.id.swBiometric)
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        
        // Load saved theme
        val savedTheme = prefs.getInt("theme_mode", AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
        when (savedTheme) {
            AppCompatDelegate.MODE_NIGHT_NO -> rgTheme.check(R.id.rbLight)
            AppCompatDelegate.MODE_NIGHT_YES -> rgTheme.check(R.id.rbDark)
            else -> rgTheme.check(R.id.rbSystem)
        }

        rgTheme.setOnCheckedChangeListener { _, checkedId ->
            val mode = when (checkedId) {
                R.id.rbLight -> AppCompatDelegate.MODE_NIGHT_NO
                R.id.rbDark -> AppCompatDelegate.MODE_NIGHT_YES
                else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
            }
            
            prefs.edit().putInt("theme_mode", mode).apply()
            AppCompatDelegate.setDefaultNightMode(mode)
        }

        // Biometric Setting
        swBiometric.isChecked = prefs.getBoolean("biometric_enabled", true)
        swBiometric.setOnCheckedChangeListener { _, isChecked ->
            prefs.edit().putBoolean("biometric_enabled", isChecked).apply()
        }

        // Admin Settings
        val isAdmin = prefs.getBoolean("isAdmin", false)
        val btnWipe = findViewById<MaterialButton>(R.id.btnWipeServerData)
        val adminDivider = findViewById<View>(R.id.adminDivider)

        if (isAdmin) {
            btnWipe.visibility = View.VISIBLE
            adminDivider.visibility = View.VISIBLE
            btnWipe.setOnClickListener { confirmWipeServerData() }
        }
        
        findViewById<MaterialButton>(R.id.btnCleanFirestore).setOnClickListener {
            confirmWipeFirestoreData()
        }

        findViewById<MaterialButton>(R.id.btnBackupCloud).setOnClickListener {
            backupData()
        }

        findViewById<MaterialButton>(R.id.btnRestoreCloud).setOnClickListener {
            restoreData()
        }
    }

    private fun backupData() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_premium_progress, null)
        val progressBar = dialogView.findViewById<com.google.android.material.progressindicator.LinearProgressIndicator>(R.id.progressBar)
        val txtStatus = dialogView.findViewById<TextView>(R.id.txtDialogStatus)
        val txtFraction = dialogView.findViewById<TextView>(R.id.txtProgressFraction)
        val btnBackground = dialogView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnBackground)
        val btnCancel = dialogView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnCancel)

        val dialog = AlertDialog.Builder(this, R.style.PremiumGlassyDialog)
            .setView(dialogView)
            .setCancelable(false)
            .create()
            
        dialog.show()
        
        btnBackground.setOnClickListener { dialog.dismiss() }
        
        val job = lifecycleScope.launch {
            FirebaseUtils.backupToRTDB(this@SettingsActivity) { current, total, _ ->
                if (current == 0) {
                    progressBar.isIndeterminate = true
                    txtStatus.text = getString(R.string.uploading_items_count, total)
                } else {
                    progressBar.isIndeterminate = false
                    progressBar.max = total
                    progressBar.progress = current
                    txtStatus.text = getString(R.string.sync_complete_status)
                }
                txtFraction.text = getString(R.string.sync_progress_status, current, total)
            }
            dialog.dismiss()
        }
        
        btnCancel.setOnClickListener {
            job.cancel()
            dialog.dismiss()
        }
    }

    private fun restoreData() {
        AlertDialog.Builder(this)
            .setTitle(R.string.restore_from_cloud_title)
            .setMessage(R.string.restore_from_cloud_msg)
            .setPositiveButton(R.string.restore) { _, _ ->
                val dialogView = layoutInflater.inflate(R.layout.dialog_premium_progress, null)
                val progressBar = dialogView.findViewById<com.google.android.material.progressindicator.LinearProgressIndicator>(R.id.progressBar)
                val txtStatus = dialogView.findViewById<TextView>(R.id.txtDialogStatus)
                val txtFraction = dialogView.findViewById<TextView>(R.id.txtProgressFraction)
                val btnBackground = dialogView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnBackground)
                val btnCancel = dialogView.findViewById<com.google.android.material.button.MaterialButton>(R.id.btnCancel)
                
                dialogView.findViewById<TextView>(R.id.txtDialogTitle).text = getString(R.string.restoring_data)
                
                val dialog = AlertDialog.Builder(this, R.style.PremiumGlassyDialog)
                    .setView(dialogView)
                    .setCancelable(false)
                    .create()
                
                dialog.show()
                
                btnBackground.setOnClickListener { dialog.dismiss() }
                
                val job = lifecycleScope.launch {
                    FirebaseUtils.restoreFromRTDB(this@SettingsActivity) { current, total, name ->
                        progressBar.max = total
                        progressBar.progress = current
                        txtStatus.text = getString(R.string.restoring_product_status, name)
                        txtFraction.text = getString(R.string.sync_progress_status, current, total)
                    }
                    dialog.dismiss()
                }
                
                btnCancel.setOnClickListener {
                    job.cancel()
                    dialog.dismiss()
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun confirmWipeFirestoreData() {
        AlertDialog.Builder(this)
            .setTitle(R.string.wipe_cloud_backups_title)
            .setMessage(R.string.wipe_cloud_backups_msg)
            .setPositiveButton(R.string.delete) { _, _ ->
                val user = FirebaseAuth.getInstance().currentUser ?: return@setPositiveButton
                
                // 1. Wipe RTDB Backup
                val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
                FirebaseDatabase.getInstance(databaseUrl).getReference("users").child(user.uid).child("products").removeValue()

                // 2. Wipe Firestore Backup (Legacy)
                val firestore = FirebaseUtils.getFirestore()
                val productsCollection = firestore.collection("backups").document(user.uid).collection("products")
                
                productsCollection.get().addOnSuccessListener { snapshot ->
                    if (!snapshot.isEmpty) {
                        val batch = firestore.batch()
                        for (doc in snapshot.documents) {
                            batch.delete(doc.reference)
                        }
                        batch.commit()
                    }
                }
                
                Toast.makeText(this, R.string.cloud_backups_deleted, Toast.LENGTH_SHORT).show()
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun confirmWipeServerData() {
        AlertDialog.Builder(this)
            .setTitle("Wipe Server Data")
            .setMessage("Are you sure you want to delete ALL product data from the server for ALL users? This action cannot be undone.")
            .setPositiveButton("Wipe Everything") { _, _ ->
                val progressDialog = AlertDialog.Builder(this)
                    .setMessage("Wiping server...")
                    .setCancelable(false)
                    .show()

                val databaseUrl = "https://aurexscannerapp-default-rtdb.firebaseio.com"
                FirebaseDatabase.getInstance(databaseUrl).getReference("products").removeValue()
                    .addOnSuccessListener {
                        progressDialog.dismiss()
                        Toast.makeText(this, "Server data wiped successfully", Toast.LENGTH_LONG).show()
                    }
                    .addOnFailureListener { e ->
                        progressDialog.dismiss()
                        Toast.makeText(this, "Wipe failed: ${e.message}", Toast.LENGTH_LONG).show()
                    }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showReauthDialog(onSuccess: () -> Unit) {
        val view = layoutInflater.inflate(R.layout.dialog_reauth, null)
        val editPassword = view.findViewById<EditText>(R.id.editConfirmPassword)

        AlertDialog.Builder(this)
            .setTitle("Confirm Identity")
            .setMessage("Please enter your current password to continue.")
            .setView(view)
            .setPositiveButton("Verify") { _, _ ->
                val password = editPassword.text.toString()
                if (password.isNotEmpty()) {
                    val user = auth.currentUser
                    val email = user?.email ?: ""
                    val credential = EmailAuthProvider.getCredential(email, password)

                    user?.reauthenticate(credential)?.addOnCompleteListener { task ->
                        if (task.isSuccessful) {
                            onSuccess()
                        } else {
                            Toast.makeText(this, "Authentication failed: ${task.exception?.message}", Toast.LENGTH_LONG).show()
                        }
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showUpdateEmailDialog() {
        val editText = EditText(this)
        editText.hint = "New Email"
        val padding = (16 * resources.displayMetrics.density).toInt()
        val container = android.widget.FrameLayout(this)
        val params = android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.WRAP_CONTENT)
        params.setMargins(padding, padding / 2, padding, padding / 2)
        editText.layoutParams = params
        container.addView(editText)

        AlertDialog.Builder(this)
            .setTitle("Change Email")
            .setView(container)
            .setPositiveButton("Update") { _, _ ->
                val newEmail = editText.text.toString().trim()
                if (newEmail.isNotEmpty()) {
                    auth.currentUser?.verifyBeforeUpdateEmail(newEmail)?.addOnCompleteListener { task ->
                        if (task.isSuccessful) {
                            Toast.makeText(this, "Verification email sent to $newEmail. Please verify to complete the change.", Toast.LENGTH_LONG).show()
                        } else {
                            Toast.makeText(this, "Error: ${task.exception?.message}", Toast.LENGTH_LONG).show()
                        }
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showUpdatePasswordDialog() {
        val editText = EditText(this)
        editText.hint = "New Password"
        editText.inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD
        val padding = (16 * resources.displayMetrics.density).toInt()
        val container = android.widget.FrameLayout(this)
        val params = android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, android.view.ViewGroup.LayoutParams.WRAP_CONTENT)
        params.setMargins(padding, padding / 2, padding, padding / 2)
        editText.layoutParams = params
        container.addView(editText)

        AlertDialog.Builder(this)
            .setTitle("Change Password")
            .setView(container)
            .setPositiveButton("Update") { _, _ ->
                val newPassword = editText.text.toString().trim()
                if (newPassword.length >= 6) {
                    auth.currentUser?.updatePassword(newPassword)?.addOnCompleteListener { task ->
                        if (task.isSuccessful) {
                            Toast.makeText(this, "Password updated successfully", Toast.LENGTH_SHORT).show()
                        } else {
                            Toast.makeText(this, "Error: ${task.exception?.message}", Toast.LENGTH_LONG).show()
                        }
                    }
                } else {
                    Toast.makeText(this, "Password must be at least 6 characters", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }
}
