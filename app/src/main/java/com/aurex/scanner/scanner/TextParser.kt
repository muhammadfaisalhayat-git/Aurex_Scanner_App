package com.aurex.scanner.scanner

import android.util.Log
import com.aurex.scanner.data.Product
import com.google.mlkit.vision.text.Text
import kotlin.math.abs

object TextParser {

    private val mfgKeywords = listOf(
        "production", "mfg", "mfd", "manufacture", "prod", "p :", "p.", "mfd date", "mfg date", "test date",
        "انتاج", "تاريخ الانتاج", "تاريخ الإنتاج", "تاريخ الصنع", "تاريخ التصنيع", "صنع", "ت.ا", "DOM", "MFD", "تعبئة", "تعبئة في", "فحص", "تاريخ الفحص", "ت الفحص", "ت. فحص", "ت.فحص"
    )

    private val expKeywords = listOf(
        "expiry", "exp", "expire", "best before", "e :", "e.", "exp.", "expiry date", "use by",
        "انتهاء", "تاريخ الانتهاء", "تاريخ الإنتهاء", "ت.هـ", "DOE", "EXP", "يستخدم قبل", "ينتهي في", "تاريخ انتهاء", "صالح حتى"
    )

    private val nameKeywords = listOf(
        "product name", "name", "variety", "product", "item", "brand",
        "اسم المنتج", "المنتج", "الاسم", "صنف", "صنف :", "المادة", "نوع", "اسم الصنف", "ماركة"
    )

    private val sizeKeywords = listOf(
        "size", "weight", "qty", "quantity", "capacity", "net", "mass", "vol",
        "الحجم", "الوزن", "الكمية", "السعة", "صافي", "الوزن الصافي", "الوزن القائم", "وزن", "الوزن عند التعبئة", "الوزن الصافي عند التعبئة", "الكمية الصافية"
    )

    private val lotKeywords = listOf(
        "lot", "batch", "رقم اللوط", "رقم التشغيلة", "رقم", "batch no", "lot no", "لوط", "رقم اللوط :"
    )

    private val validityKeywords = listOf(
        "validity", "period", "duration", "الصلاحية", "صالح لمدة", "صلاحية", "مدة الصلاحية", "فترة الصلاحية", "تاريخ الصلاحية"
    )

    private val datePatterns = listOf(
        // Standard numeric patterns with various separators
        Regex("""\b\d{1,2}\s*[./-]\s*\d{1,2}\s*[./-]\s*\d{4}\b"""), // 12/12/2024
        Regex("""\b\d{1,2}\s*[./-]\s*\d{1,2}\s*[./-]\s*\d{2}\b"""),   // 12/12/24
        Regex("""\b\d{4}\s*[./-]\s*\d{1,2}\s*[./-]\s*\d{1,2}\b"""),   // 2024/12/12
        Regex("""\b\d{1,2}\s*[./-]\s*\d{4}\b"""),                     // 12/2024
        Regex("""\b\d{4}\s*[./-]\s*\d{1,2}\b"""),                     // 2024/12
        Regex("""\b\d{1,2}\s*[./-]\s*\d{2}\b"""),                     // 12/25
        
        // English Textual Dates
        Regex("""\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2}t?h?,?\s+\d{4}\b""", RegexOption.IGNORE_CASE),
        Regex("""\b\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4}\b""", RegexOption.IGNORE_CASE),
        Regex("""\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4}\b""", RegexOption.IGNORE_CASE),
        
        // Arabic Textual Dates
        Regex("""\b(يناير|فبراير|مارس|أبريل|مايو|يونيو|يوليو|أغسطس|سبتمبر|أكتوبر|نوفمبر|ديسمبر)\s+\d{4}\b"""),
        Regex("""\b\d{1,2}\s+(يناير|فبراير|مارس|أبريل|مايو|يونيو|يوليو|أغسطس|سبتمبر|أكتوبر|نوفمبر|ديسمبر)\s+\d{4}\b"""),
        
        // No-separator formats (Stricter validation required for these)
        Regex("""\b\d{8}\b"""), // YYYYMMDD
        Regex("""\b\d{6}\b""")  // MMYYYY or DDMMYY
    )

    private val unitRegex = Regex("""(\d+\.?\d*)\s*(kg|g|l|ml|liter|litres|gram|kilogram|kgm|مل|جم|كجم|لتر)""", RegexOption.IGNORE_CASE)

    fun parseRaw(rawText: String): Product {
        Log.d("TextParser", "Parsing raw text: $rawText")
        val dateElements = mutableListOf<String>()
        var foundQuantity = "1"
        var foundSize: String? = null
        var foundProductCode: String = ""
        
        val normalizedRaw = normalizeDigits(rawText)
        
        // Detect size/weight
        unitRegex.find(normalizedRaw)?.let {
            foundSize = it.value
        }
        
        // Look for Product Code/Batch
        for (key in lotKeywords) {
            if (normalizedRaw.lowercase().contains(key.lowercase())) {
                val value = normalizedRaw.lowercase().substringAfter(key.lowercase()).trim(':').trim()
                val code = value.split(Regex("""\s""")).firstOrNull() ?: ""
                if (code.length >= 2) foundProductCode = code
            }
        }
        
        // Extract all dates
        extractDates(normalizedRaw).forEach { dateElements.add(it) }

        val allUniqueDates = dateElements.distinct()
        var finalMfg: String? = null
        var finalExp: String? = null

        val lowerRaw = normalizedRaw.lowercase()
        for (date in allUniqueDates) {
            val escapedDate = Regex.escape(date).replace("/", "[./-]")
            val match = Regex(escapedDate).find(lowerRaw)
            val idx = match?.range?.first ?: -1
            val context = if (idx != -1) lowerRaw.substring(maxOf(0, idx - 40), minOf(lowerRaw.length, idx + 60)) else ""
            
            if (mfgKeywords.any { context.contains(it.lowercase()) } && finalMfg == null) {
                finalMfg = date
            } else if (expKeywords.any { context.contains(it.lowercase()) } && finalExp == null) {
                finalExp = date
            }
        }

        // Fallback for dates
        if (allUniqueDates.size >= 2) {
            val sorted = sortDateStrings(allUniqueDates)
            if (finalMfg == null && finalExp == null) {
                finalMfg = sorted.first()
                finalExp = sorted.last()
            } else if (finalMfg != null && finalExp == null) {
                finalExp = allUniqueDates.find { it != finalMfg }
            } else if (finalExp != null && finalMfg == null) {
                finalMfg = allUniqueDates.find { it != finalExp }
            }
            
            if (finalMfg != null && finalExp != null && isSecondBeforeFirst(finalExp!!, finalMfg!!)) {
                val temp = finalMfg
                finalMfg = finalExp
                finalExp = temp
            }
        } else if (allUniqueDates.size == 1 && finalExp == null) {
            finalExp = allUniqueDates.first()
        }

        return Product(
            productCode = foundProductCode,
            name = extractSmartNameFromRaw(rawText),
            mfgDate = finalMfg,
            expDate = finalExp,
            quantity = foundQuantity,
            size = foundSize
        )
    }

    private fun extractDates(text: String): List<String> {
        val found = mutableListOf<String>()
        for (pattern in datePatterns) {
            pattern.findAll(text).forEach { match ->
                var raw = match.value.trim()
                if (raw.any { it.isLetter() }) {
                    convertTextDateToNumeric(raw)?.let { found.add(it) }
                } else {
                    raw = raw.replace(" ", "")
                    // Heuristic for no-separator dates
                    if (raw.length == 8 && !raw.contains("/") && !raw.contains(".") && !raw.contains("-")) {
                         // Check if it looks like a date (e.g., month isn't 35)
                         val m1 = raw.substring(0, 2).toInt()
                         val m2 = raw.substring(2, 4).toInt()
                         if (m1 in 1..12 || m2 in 1..12) {
                             raw = "${raw.substring(0,2)}/${raw.substring(2,4)}/${raw.substring(4)}"
                         } else return@forEach
                    } else if (raw.length == 6 && !raw.contains("/") && !raw.contains(".") && !raw.contains("-")) {
                         raw = "${raw.substring(0,2)}/${raw.substring(2,4)}/${raw.substring(4)}"
                    }
                    val dateVal = raw.replace(".", "/").replace("-", "/")
                    if (isValidDate(dateVal)) found.add(dateVal)
                }
            }
        }
        return found
    }

    private fun extractSmartNameFromRaw(rawText: String): String {
        val lines = rawText.lines().filter { it.isNotBlank() }
        val noise = Regex("""(?i)batch|lot|weight|net|tel|phone|price|egp|le|pcs|size|qty|\d|انتاج|فحص|تاريخ|exp|mfg|prod|date|expiry""")
        for (line in lines.take(5)) {
            val trimmed = line.trim().substringBefore("Prod").substringBefore("EXP").trim()
            if (trimmed.length > 4 && !noise.containsMatchIn(trimmed)) return trimmed
        }
        return lines.firstOrNull()?.substringBefore(":")?.trim() ?: "Unknown Product"
    }

    fun parse(mlText: Text): Product {
        val dateElements = mutableListOf<DateElement>()
        var foundQuantity = "1"
        var foundSize: String? = null
        var foundProductCode: String = ""
        var foundValidityText = ""
        
        val fullText = normalizeDigits(mlText.text)
        unitRegex.find(fullText)?.let {
            foundSize = it.value
        }

        for (block in mlText.textBlocks) {
            val normalizedBlockText = normalizeDigits(block.text).lowercase()
            for (key in lotKeywords) {
                if (normalizedBlockText.contains(key.lowercase())) {
                    val value = normalizedBlockText.substringAfter(key.lowercase()).trim(':').trim()
                    val code = value.split(Regex("""\s""")).firstOrNull() ?: ""
                    if (code.length >= 2) foundProductCode = code
                }
            }
            for (key in validityKeywords) {
                if (normalizedBlockText.contains(key.lowercase())) foundValidityText = block.text
            }

            for (line in block.lines) {
                val normalizedLine = normalizeDigits(line.text)
                val lowerLine = normalizedLine.lowercase()
                
                // Extraction
                for (key in sizeKeywords) {
                    if (lowerLine.contains(key.lowercase())) {
                        val value = normalizedLine.substringAfter(key.lowercase(), "").trim(':').trim()
                        val firstWord = value.split(Regex("""\s""")).firstOrNull() ?: ""
                        if (firstWord.any { it.isDigit() }) foundQuantity = firstWord
                    }
                }
                
                extractDates(normalizedLine).forEach { dateElements.add(DateElement(it, line)) }
            }
        }

        var finalMfg: String? = null
        var finalExp: String? = null
        var mfgBox: String? = null
        var expBox: String? = null

        for (dateElem in dateElements) {
            val dateBox = dateElem.line.boundingBox ?: continue
            var bestType = 0 
            var minDist = 400f
            
            for (block in mlText.textBlocks) {
                val bBox = block.boundingBox ?: continue
                val bText = block.text.lowercase()
                val dist = abs(bBox.centerY() - dateBox.centerY()).toFloat() + abs(bBox.left - dateBox.left).toFloat() * 0.5f
                
                if (dist < minDist) {
                    if (mfgKeywords.any { bText.contains(it) }) { bestType = 1; minDist = dist }
                    else if (expKeywords.any { bText.contains(it) }) { bestType = 2; minDist = dist }
                }
            }

            if (bestType == 1 && finalMfg == null) {
                finalMfg = dateElem.value
                mfgBox = "${dateBox.left},${dateBox.top},${dateBox.right},${dateBox.bottom}"
            } else if (bestType == 2 && finalExp == null) {
                finalExp = dateElem.value
                expBox = "${dateBox.left},${dateBox.top},${dateBox.right},${dateBox.bottom}"
            }
        }

        val allUniqueDates = dateElements.map { it.value }.distinct()
        if (allUniqueDates.size >= 2) {
            val sorted = sortDateStrings(allUniqueDates)
            if (finalMfg == null && finalExp == null) {
                finalMfg = sorted.first(); finalExp = sorted.last()
            } else if (finalMfg != null && finalExp == null) {
                finalExp = allUniqueDates.find { it != finalMfg }
            } else if (finalExp != null && finalMfg == null) {
                finalMfg = allUniqueDates.find { it != finalExp }
            }
            if (finalMfg != null && finalExp != null && isSecondBeforeFirst(finalExp, finalMfg)) {
                val t = finalMfg; finalMfg = finalExp; finalExp = t
            }
        } else if (allUniqueDates.size == 1) {
            if (finalMfg != null || foundValidityText.isNotEmpty()) {
                finalMfg = allUniqueDates.first()
                finalExp = calculateExpiry(finalMfg, foundValidityText)
            } else {
                finalExp = allUniqueDates.first()
            }
        }

        return Product(
            productCode = foundProductCode,
            name = extractSmartName(mlText, foundProductCode),
            mfgDate = finalMfg,
            expDate = finalExp,
            quantity = foundQuantity,
            size = foundSize,
            mfgBox = mfgBox,
            expBox = expBox
        )
    }

    private fun calculateExpiry(base: String?, validity: String?): String? {
        if (base == null) return null
        var y = 1; var m = 0
        val low = validity?.lowercase() ?: ""
        if (low.contains("سنتين") || low.contains("2 years")) y = 2
        else if (low.contains("سنة") || low.contains("1 year")) y = 1
        return addTimeToDate(base, y, m)
    }

    private fun addTimeToDate(date: String, years: Int, months: Int): String? {
        val parts = date.split('/')
        return try {
            var y = parts.last().toInt().let { if (it < 100) 2000 + it else it }
            var m = if (parts.size >= 2) parts[parts.size - 2].toInt() else 1
            val d = if (parts.size == 3) parts[0].toInt() else 1
            m += months; y += years + (m - 1) / 12; m = (m - 1) % 12 + 1
            "${d.toString().padStart(2,'0')}/${m.toString().padStart(2,'0')}/$y"
        } catch (e: Exception) { null }
    }

    private fun extractSmartName(mlText: Text, lot: String): String {
        val candidates = mutableListOf<NameCandidate>()
        val noise = Regex("""(?i)batch|lot|weight|net|tel|phone|price|egp|le|pcs|size|qty|\d|انتاج|فحص|تاريخ|exp|mfg|prod|date|expiry""")
        
        for (block in mlText.textBlocks) {
            val text = block.text.trim().replace("\n", " ").substringBefore("Prod").substringBefore("EXP").trim()
            if (text.length < 3 || noise.containsMatchIn(text)) continue
            val score = (block.boundingBox?.height() ?: 0).toDouble() / (block.boundingBox?.top ?: 1 + 100)
            candidates.add(NameCandidate(text, score))
        }
        
        var name = candidates.maxByOrNull { it.score }?.text ?: "Unknown Product"
        if (lot.isNotEmpty() && !name.contains(lot)) name += " ($lot)"
        return name
    }

    private fun convertTextDateToNumeric(text: String): String? {
        val ms = mapOf("jan" to "01", "feb" to "02", "mar" to "03", "apr" to "04", "may" to "05", "jun" to "06", "jul" to "07", "aug" to "08", "sep" to "09", "oct" to "10", "nov" to "11", "dec" to "12", "يناير" to "01", "فبراير" to "02", "مارس" to "03", "أبريل" to "04", "مايو" to "05", "يونيو" to "06", "يوليو" to "07", "أغسطس" to "08", "سبتمبر" to "09", "أكتوبر" to "10", "نوفمبر" to "11", "ديسمبر" to "12")
        return try {
            val low = text.lowercase()
            val mk = ms.keys.find { low.contains(it) } ?: return null
            val mv = ms[mk]!!
            val ds = Regex("""\d+""").findAll(text).map { it.value }.toList()
            if (ds.size < 1) return null
            val y = ds.last().let { if (it.length == 2) "20$it" else it }
            val d = if (ds.size > 1) ds[0].padStart(2, '0') else "01"
            "$d/$mv/$y"
        } catch (e: Exception) { null }
    }

    private data class NameCandidate(val text: String, val score: Double)

    private fun normalizeDigits(input: String): String {
        val m = mapOf('٠' to '0', '١' to '1', '٢' to '2', '٣' to '3', '٤' to '4', '٥' to '5', '٦' to '6', '٧' to '7', '٨' to '8', '٩' to '9', 'o' to '0', 'O' to '0', 'l' to '1', 'I' to '1', 's' to '5', 'S' to '5', 'b' to '6', 'z' to '2')
        return input.map { m[it] ?: it }.joinToString("")
    }

    private fun isValidDate(date: String): Boolean {
        val p = date.split('/')
        return try {
            val d1 = p[0].toInt(); val d2 = p.last().toInt()
            val m = if (p.size >= 2) p[p.size-2].toInt() else 1
            (m in 1..12) && ((d1 in 2020..2040) || (d1 in 1..31 && d2 in 20..40) || (d1 in 1..31 && d2 in 2020..2040))
        } catch (e: Exception) { false }
    }

    private data class DateElement(val value: String, val line: Text.Line)
    private fun isSecondBeforeFirst(d1: String, d2: String) = convertToSortable(d1) <= convertToSortable(d2)

    fun isExpired(expDate: String?): Boolean {
        if (expDate == null) return false
        return try {
            val sdf = java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.US)
            convertToSortable(expDate) < sdf.format(java.util.Date())
        } catch (e: Exception) { false }
    }

    fun isNearExpiry(exp: String?): Boolean {
        if (exp == null) return false
        return try {
            val sdf = java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.US)
            val d = sdf.parse(convertToSortable(exp)) ?: return false
            val diff = d.time - java.util.Date().time
            diff / (1000 * 60 * 60 * 24) in 0..30
        } catch (e: Exception) { false }
    }

    fun convertToSortable(date: String): String {
        val p = date.split('/')
        var y = "2000"; var m = "01"; var d = "01"
        try {
            if (p.size == 2) {
                if (p[1].toInt() > 50) { y = p[1]; m = p[0] } else { y = "20" + p[1]; m = p[0] }
            } else if (p.size == 3) {
                if (p[0].length == 4) { y = p[0]; m = p[1]; d = p[2] }
                else { y = p[2]; m = p[1]; d = p[0] }
            }
            if (y.length == 2) y = "20$y"
        } catch (e: Exception) {}
        return y.padStart(4,'0') + m.padStart(2,'0') + d.padStart(2,'0')
    }

    private fun sortDateStrings(dates: List<String>) = dates.sortedBy { convertToSortable(it) }
}
