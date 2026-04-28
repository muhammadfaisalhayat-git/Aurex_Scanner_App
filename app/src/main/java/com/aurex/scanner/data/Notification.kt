package com.aurex.scanner.data

data class Notification(
    var id: String = "",
    var title: String = "",
    var message: String = "",
    var type: String = "info", // "info", "warning", "action", "approval"
    var timestamp: Long = System.currentTimeMillis(),
    var read: Boolean = false,
    var actionData: String? = null // e.g., userId for approvals
)
