package com.aurex.scanner.ui

import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.aurex.scanner.data.AppDatabase
import com.aurex.scanner.data.Product
import kotlinx.coroutines.launch

class ResultActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val product = intent.getSerializableExtra("data") as? Product ?: return

        val textView = TextView(this).apply {
            setPadding(32, 32, 32, 32)
            textSize = 18f
            text = """
                Product Name: ${product.name}
                MFG Date: ${product.mfgDate ?: "Not found"}
                EXP Date: ${product.expDate ?: "Not found"}
            """.trimIndent()
        }

        val saveBtn = Button(this).apply {
            text = "SAVE TO DATABASE"
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(textView)
            addView(saveBtn)
        }

        setContentView(layout)

        saveBtn.setOnClickListener {
            val db = AppDatabase.getDatabase(this)
            lifecycleScope.launch {
                db.productDao().insert(product)
                saveBtn.text = "SAVED ✓"
                saveBtn.isEnabled = false
            }
        }
    }
}
