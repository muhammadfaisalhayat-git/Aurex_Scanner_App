package com.aurex.scanner.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.io.Serializable

@Entity
data class Product(
    @PrimaryKey var productCode: String = "",
    var id: Long = 0, // Keep id for internal ordering if needed, but not as PK
    var name: String = "",
    var mfgDate: String? = null,
    var expDate: String? = null,
    var quantity: String = "1",
    var size: String? = null, // e.g., "500ml", "1kg"
    var category: String? = "General",
    var imagePath: String? = null,
    var warehouseName: String? = null,
    var barcode: String? = null,
    var mfgBox: String? = null, // Store as "left,top,right,bottom"
    var expBox: String? = null,  // Store as "left,top,right,bottom"
    var isSynced: Boolean = false
) : Serializable
