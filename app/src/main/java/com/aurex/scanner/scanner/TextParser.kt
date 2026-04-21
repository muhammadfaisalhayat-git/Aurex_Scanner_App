package com.aurex.scanner.scanner

import com.aurex.scanner.data.Product

object TextParser {

    private val mfgKeywords = listOf(
        "production date", "mfg", "mfd", "date of manufacture", "prod date",
        "انتاج", "تاريخ الانتاج", "تاريخ الإنتاج", "تاريخ التصنيع"
    )

    private val expKeywords = listOf(
        "expiry", "exp", "expire", "best before", "exp date", "expier",
        "انتهاء", "تاريخ الانتهاء", "تاريخ الصلاحية"
    )

    private val datePatterns = listOf(
        Regex("""\b\d{1,2}[/-]\d{2}[/-]\d{4}\b"""), // 12/05/2025
        Regex("""\b\d{1,2}[/-]\d{4}\b"""),           // 9/2025 or 09/2025
        Regex("""\b\d{4}[/-]\d{1,2}\b"""),           // 2025/9
        Regex("""\b\d{1,2}[/-]\d{2}\b"""),           // 05/25
        Regex("""\b\d{4}\b""")                        // 2025
    )

    fun parse(text: String): Product {
        val clean = normalizeText(text)

        val mfg = findDate(clean, mfgKeywords)
        val exp = findDate(clean, expKeywords)

        var finalMfg = mfg
        var finalExp = exp

        // Fallback: if no labels found → use min/max logic
        if (finalMfg == null || finalExp == null) {
            val allDates = datePatterns.flatMap { pattern ->
                pattern.findAll(clean).map { it.value }
            }.distinct()

            if (allDates.size >= 2) {
                val sorted = allDates.sorted()
                if (finalMfg == null) finalMfg = sorted.first()
                if (finalExp == null) finalExp = sorted.last()
            } else if (allDates.size == 1 && finalExp == null) {
                finalExp = allDates.first()
            }
        }

        return Product(
            name = extractName(text),
            mfgDate = finalMfg,
            expDate = finalExp
        )
    }

    private fun normalizeText(text: String): String {
        return text
            .replace("٠", "0")
            .replace("١", "1")
            .replace("٢", "2")
            .replace("٣", "3")
            .replace("٤", "4")
            .replace("٥", "5")
            .replace("٦", "6")
            .replace("٧", "7")
            .replace("٨", "8")
            .replace("٩", "9")
            .replace("\n", " ")
            .replace(Regex("\\s+"), " ")
            .lowercase()
    }

    private fun findDate(text: String, keywords: List<String>): String? {
        for (key in keywords) {
            val index = text.indexOf(key)
            if (index != -1) {
                val searchWindow = 150
                val start = index + key.length
                val end = (start + searchWindow).coerceAtMost(text.length)
                val subText = text.substring(start, end)

                for (pattern in datePatterns) {
                    val match = pattern.find(subText)
                    if (match != null) return match.value
                }
            }
        }
        return null
    }

    private fun extractName(text: String): String {
        // Simple logic: first line that isn't empty or just a date
        return text.lines()
            .map { it.trim() }
            .firstOrNull { it.isNotEmpty() && !it.contains(Regex("\\d")) } ?: "Unknown Product"
    }
}
