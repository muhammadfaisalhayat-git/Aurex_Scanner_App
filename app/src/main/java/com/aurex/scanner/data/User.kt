package com.aurex.scanner.data

data class User(
    var id: String = "",
    var name: String = "",
    var email: String = "",
    var position: String = "",
    var isAdmin: Boolean = false,
    var isApproved: Boolean = false,
    var dailyScans: Int = 0 // New field for UI display
)
