package com.aurex.scanner.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.io.Serializable

@Entity
data class Product(
    @PrimaryKey(autoGenerate = true) var id: Long = 0,
    var productCode: String = "",
    var name: String = "",
    var mfgDate: String? = null,
    var expDate: String? = null,
    var quantity: String = "1",
    var size: String? = null,
    var category: String? = "General",
    var imagePath: String? = null,
    var warehouseName: String? = null,
    var barcode: String? = null,
    var mfgBox: String? = null,
    var expBox: String? = null,
    var isSynced: Boolean = false,
    
    // Multi-tenant fields
    var groupId: String? = "lafi_al_harbi_group", // Default Tenant
    var companyId: String? = "bin_awf"           // Default Company
) : Serializable
