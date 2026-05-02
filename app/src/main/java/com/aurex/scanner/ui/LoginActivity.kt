package com.aurex.scanner.ui

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.*
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.aurex.scanner.R
import com.aurex.scanner.data.User
import com.aurex.scanner.util.FirebaseUtils
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.ValueEventListener
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.Executor

class LoginActivity : BaseActivity() {

    private lateinit var auth: FirebaseAuth
    private val RC_SIGN_IN = 9001
    private var isRegistering = false
    private lateinit var executor: Executor
    private lateinit var biometricPrompt: BiometricPrompt
    private lateinit var promptInfo: BiometricPrompt.PromptInfo
    private lateinit var loginProgress: ProgressBar
    private lateinit var btnBiometric: ImageButton

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_login)

        auth = FirebaseAuth.getInstance()
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)

        val emailEdit = findViewById<EditText>(R.id.editEmail)
        val passwordEdit = findViewById<EditText>(R.id.editPassword)
        val warehouseNameEdit = findViewById<EditText>(R.id.editWarehouseName)
        val warehouseCodeEdit = findViewById<EditText>(R.id.editWarehouseCode)
        val btnLogin = findViewById<Button>(R.id.btnLogin)
        val btnGoogle = findViewById<Button>(R.id.btnGoogleSignIn)
        val btnRegister = findViewById<Button>(R.id.btnRegister)
        val cbRememberMe = findViewById<CheckBox>(R.id.cbRememberMe)
        val txtForgotPassword = findViewById<TextView>(R.id.txtForgotPassword)
        val btnSwitchLanguage = findViewById<TextView>(R.id.btnSwitchLanguage)
        loginProgress = findViewById(R.id.loginProgress)
        btnBiometric = findViewById(R.id.btnBiometric)

        setupBiometric()

        btnBiometric.setOnClickListener {
            biometricPrompt.authenticate(promptInfo)
        }

        btnSwitchLanguage.setOnClickListener {
            val currentLang = resources.configuration.locales[0].language
            val newLang = if (currentLang == "ar") "en" else "ar"
            com.aurex.scanner.util.LocaleHelper.setLocale(this, newLang)
            val intent = Intent(this, LoginActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            startActivity(intent)
            finish()
        }

        btnRegister.setOnClickListener {
            if (!isRegistering) {
                isRegistering = true
                warehouseNameEdit.visibility = View.VISIBLE
                warehouseCodeEdit.visibility = View.VISIBLE
                btnLogin.text = "Create Account"
                btnRegister.text = "Back to Login"
            } else {
                isRegistering = false
                warehouseNameEdit.visibility = View.GONE
                warehouseCodeEdit.visibility = View.GONE
                btnLogin.text = "Login"
                btnRegister.text = "Register"
            }
        }

        txtForgotPassword.setOnClickListener {
            showForgotPasswordDialog()
        }

        btnLogin.setOnClickListener {
            val email = emailEdit.text.toString().trim()
            val pass = passwordEdit.text.toString().trim()
            val wName = warehouseNameEdit.text.toString().trim()
            val wCode = warehouseCodeEdit.text.toString().trim()

            if (email.isNotEmpty() && pass.isNotEmpty()) {
                setLoading(true)
                if (isRegistering) {
                    if (wName.isEmpty() || wCode.isEmpty()) {
                        setLoading(false)
                        Toast.makeText(this, "Please enter warehouse details", Toast.LENGTH_SHORT).show()
                        return@setOnClickListener
                    }
                    lifecycleScope.launch {
                        try {
                            auth.createUserWithEmailAndPassword(email, pass).await()
                            val userId = auth.currentUser?.uid ?: ""
                            val isAdmin = email.lowercase().trim() == "admin@aurex.com"
                            
                            val userProfile = User(
                                id = userId, 
                                name = email.split("@")[0], 
                                email = email, 
                                position = wName, 
                                isAdmin = isAdmin,
                                isApproved = isAdmin
                            )
                            
                            FirebaseUtils.getDatabase().getReference("users").child(userId).setValue(userProfile).await()
                            
                            if (!isAdmin) {
                                com.aurex.scanner.util.NotificationHelper.sendNotification("admin", com.aurex.scanner.data.Notification(
                                    title = "New User Registration",
                                    message = "User $email is requesting access.",
                                    type = "approval",
                                    actionData = userId
                                ))
                                com.aurex.scanner.util.NotificationHelper.showSystemNotification(this@LoginActivity, "Registration Successful", "Pending admin approval.")
                            }

                            if (isAdmin) {
                                prefs.edit().putBoolean("rememberMe", cbRememberMe.isChecked).putBoolean("isAdmin", true).putString("warehouseName", wName).putString("warehouseCode", wCode).apply()
                                setLoading(false)
                                startMainActivity()
                            } else {
                                auth.signOut()
                                setLoading(false)
                                androidx.appcompat.app.AlertDialog.Builder(this@LoginActivity)
                                    .setTitle("Registration Successful")
                                    .setMessage("Your account is pending admin approval.")
                                    .setPositiveButton("OK", null)
                                    .show()
                                isRegistering = false
                                warehouseNameEdit.visibility = View.GONE
                                warehouseCodeEdit.visibility = View.GONE
                                btnLogin.text = "Login"
                                btnRegister.text = "Register"
                            }
                        } catch (e: Exception) {
                            setLoading(false)
                            Toast.makeText(this@LoginActivity, "Registration Failed: ${e.localizedMessage}", Toast.LENGTH_SHORT).show()
                        }
                    }
                } else {
                    performLogin(email, pass, cbRememberMe.isChecked)
                }
            } else {
                Toast.makeText(this, "Please fill all fields", Toast.LENGTH_SHORT).show()
            }
        }

        btnGoogle.setOnClickListener {
            val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestIdToken(getString(R.string.default_web_client_id))
                .requestEmail()
                .build()
            val googleSignInClient = GoogleSignIn.getClient(this, gso)
            googleSignInClient.signOut().addOnCompleteListener {
                val signInIntent = googleSignInClient.signInIntent
                startActivityForResult(signInIntent, RC_SIGN_IN)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RC_SIGN_IN) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(data)
            try {
                val account = task.getResult(com.google.android.gms.common.api.ApiException::class.java)!!
                val credential = GoogleAuthProvider.getCredential(account.idToken, null)
                setLoading(true)

                lifecycleScope.launch {
                    try {
                        auth.signInWithCredential(credential).await()
                        val user = auth.currentUser
                        val userId = user?.uid ?: ""
                        val email = user?.email ?: ""

                        // Fetch profile with increased timeout
                        val userRef = FirebaseUtils.getDatabase().getReference("users").child(userId)
                        val snapshot = withTimeoutOrNull(30000L) {
                            userRef.get().await()
                        }

                        if (snapshot == null) {
                            // On timeout, we still have the Auth session. 
                            // Try one more time with a direct listener which is more reliable for the first handshake
                            checkProfileWithListener(userId, email, account.displayName)
                            return@launch
                        }

                        processLoginSnapshot(snapshot, userId, email, account.displayName)
                        
                    } catch (e: Exception) {
                        setLoading(false)
                        auth.signOut()
                        Log.e("LoginActivity", "Google Auth Error", e)
                        Toast.makeText(this@LoginActivity, "Login Failed: ${e.localizedMessage}", Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: com.google.android.gms.common.api.ApiException) {
                setLoading(false)
                if (e.statusCode != 12501) {
                    Toast.makeText(this, "Sign-In Error (Code: ${e.statusCode})", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                setLoading(false)
                Toast.makeText(this, "An unexpected error occurred", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun checkProfileWithListener(userId: String, email: String, displayName: String?) {
        val userRef = FirebaseUtils.getDatabase().getReference("users").child(userId)
        userRef.addListenerForSingleValueEvent(object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                if (!isDestroyed && !isFinishing) {
                    processLoginSnapshot(snapshot, userId, email, displayName)
                }
            }
            override fun onCancelled(error: DatabaseError) {
                setLoading(false)
                auth.signOut()
                Toast.makeText(this@LoginActivity, "Connection Error: ${error.message}", Toast.LENGTH_LONG).show()
            }
        })
    }

    private fun processLoginSnapshot(snapshot: DataSnapshot, userId: String, email: String, displayName: String?) {
        if (snapshot.exists()) {
            val userProfile = snapshot.getValue(User::class.java)
            if (userProfile?.isApproved == true) {
                getSharedPreferences("AurexPrefs", MODE_PRIVATE).edit().putBoolean("rememberMe", true).putBoolean("isAdmin", userProfile.isAdmin).apply()
                setLoading(false)
                startMainActivity()
            } else {
                auth.signOut()
                setLoading(false)
                Toast.makeText(this@LoginActivity, "Account pending approval.", Toast.LENGTH_LONG).show()
            }
        } else {
            // New Registration
            val isAdmin = email.lowercase().trim() == "admin@aurex.com"
            val newUser = User(
                id = userId,
                name = displayName ?: email.split("@")[0],
                email = email,
                position = "Google User",
                isAdmin = isAdmin,
                isApproved = isAdmin
            )
            
            lifecycleScope.launch {
                try {
                    FirebaseUtils.getDatabase().getReference("users").child(userId).setValue(newUser).await()
                    setLoading(false)
                    if (isAdmin) {
                        getSharedPreferences("AurexPrefs", MODE_PRIVATE).edit().putBoolean("rememberMe", true).putBoolean("isAdmin", true).apply()
                        startMainActivity()
                    } else {
                        com.aurex.scanner.util.NotificationHelper.sendNotification("admin", com.aurex.scanner.data.Notification(
                            title = "New Google User",
                            message = "User $email registered.",
                            type = "approval",
                            actionData = userId
                        ))
                        auth.signOut()
                        androidx.appcompat.app.AlertDialog.Builder(this@LoginActivity)
                            .setTitle("Success")
                            .setMessage("Registered. Waiting for Admin approval.")
                            .setPositiveButton("OK", null)
                            .show()
                    }
                } catch (e: Exception) {
                    setLoading(false)
                    auth.signOut()
                    Toast.makeText(this@LoginActivity, "Registration error: ${e.localizedMessage}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun performLogin(email: String, pass: String, rememberMe: Boolean) {
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        setLoading(true)
        lifecycleScope.launch {
            try {
                auth.signInWithEmailAndPassword(email, pass).await()
                val user = auth.currentUser
                val userId = user?.uid ?: ""
                val emailTrimmed = email.lowercase().trim()
                
                if (emailTrimmed == "admin@aurex.com") {
                    prefs.edit().putBoolean("rememberMe", rememberMe).putBoolean("isAdmin", true).putString("savedEmail", email).putString("savedPass", pass).apply()
                    setLoading(false)
                    startMainActivity()
                    return@launch
                }

                val snapshot = withTimeoutOrNull(30000L) {
                    FirebaseUtils.getDatabase().getReference("users").child(userId).get().await()
                }

                if (snapshot == null) {
                    // Timeout retry with listener
                    checkProfileWithListener(userId, email, null)
                    return@launch
                }

                processLoginSnapshot(snapshot, userId, email, null)
                
            } catch (e: Exception) {
                setLoading(false)
                Toast.makeText(this@LoginActivity, e.localizedMessage ?: "Login Failed", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun setLoading(isLoading: Boolean) {
        val btnLogin = findViewById<Button>(R.id.btnLogin)
        if (isLoading) {
            btnLogin.isEnabled = false
            btnLogin.alpha = 0.5f
            loginProgress.visibility = View.VISIBLE
        } else {
            btnLogin.isEnabled = true
            btnLogin.alpha = 1.0f
            loginProgress.visibility = View.GONE
        }
    }

    private fun setupBiometric() {
        val biometricManager = BiometricManager.from(this)
        val prefs = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
        val isBiometricEnabledInSettings = prefs.getBoolean("biometric_enabled", true)

        if (!isBiometricEnabledInSettings) {
            btnBiometric.visibility = View.GONE
            return
        }

        when (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL)) {
            BiometricManager.BIOMETRIC_SUCCESS -> {
                val savedEmail = prefs.getString("savedEmail", null)
                val savedPass = prefs.getString("savedPass", null)
                if (savedEmail != null && savedPass != null) btnBiometric.visibility = View.VISIBLE
            }
            else -> btnBiometric.visibility = View.GONE
        }

        executor = ContextCompat.getMainExecutor(this)
        biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    Toast.makeText(applicationContext, "Auth error: $errString", Toast.LENGTH_SHORT).show()
                }
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    val p = getSharedPreferences("AurexPrefs", MODE_PRIVATE)
                    val e = p.getString("savedEmail", "") ?: ""
                    val ps = p.getString("savedPass", "") ?: ""
                    if (e.isNotEmpty() && ps.isNotEmpty()) {
                        setLoading(true)
                        performLogin(e, ps, true)
                    }
                }
                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    Toast.makeText(applicationContext, "Auth failed", Toast.LENGTH_SHORT).show()
                }
            })

        promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(getString(R.string.biometric_login))
            .setSubtitle(getString(R.string.biometric_login_desc))
            .setNegativeButtonText(getString(R.string.cancel))
            .build()
    }

    private fun startMainActivity() {
        startActivity(Intent(this, MainActivity::class.java))
        finish()
    }

    private fun showForgotPasswordDialog() {
        val emailInput = EditText(this)
        emailInput.hint = getString(R.string.enter_registered_email)
        emailInput.setPadding(50, 40, 50, 40)
        val dialog = androidx.appcompat.app.AlertDialog.Builder(this)
            .setTitle(getString(R.string.reset_password))
            .setMessage(getString(R.string.reset_password_message))
            .setView(emailInput)
            .setPositiveButton(getString(R.string.send_link), null)
            .setNegativeButton(getString(R.string.cancel), null)
            .create()

        dialog.setOnShowListener {
            val button = dialog.getButton(androidx.appcompat.app.AlertDialog.BUTTON_POSITIVE)
            button.setOnClickListener {
                val email = emailInput.text.toString().trim()
                if (email.isEmpty()) {
                    emailInput.error = "Email is required"
                    return@setOnClickListener
                }
                setLoading(true)
                button.isEnabled = false
                auth.sendPasswordResetEmail(email)
                    .addOnCompleteListener { task ->
                        setLoading(false)
                        button.isEnabled = true
                        if (task.isSuccessful) {
                            dialog.dismiss()
                            androidx.appcompat.app.AlertDialog.Builder(this@LoginActivity)
                                .setTitle(getString(R.string.success))
                                .setMessage(getString(R.string.reset_link_sent_msg, email))
                                .setPositiveButton(getString(R.string.ok), null)
                                .show()
                        } else {
                            val errorMsg = task.exception?.message ?: "Unknown error"
                            if (errorMsg.contains("no user record", ignoreCase = true)) {
                                emailInput.error = getString(R.string.error_user_not_found)
                            } else {
                                Toast.makeText(this@LoginActivity, "Error: $errorMsg", Toast.LENGTH_SHORT).show()
                            }
                        }
                    }
            }
        }
        dialog.show()
    }
}
