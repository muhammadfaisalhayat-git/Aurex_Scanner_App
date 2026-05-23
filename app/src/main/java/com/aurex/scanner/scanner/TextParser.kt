package com.aurex.scanner.scanner

import android.util.Log
import com.aurex.scanner.data.Product
import com.google.mlkit.vision.text.Text
import kotlin.math.abs

object TextParser {

    private val mfgKeywords = listOf(
        "production", "mfg", "mfd", "manufacture", "prod", "p:", "p :", "p.", "mfd date", "mfg date", "test date", "date of product", "date of production", "production date", "packed", "packing date", "pkd",
        "انتاج", "تاريخ الانتاج", "تاريخ الإنتاج", "تاريخ الصنع", "تاريخ التصنيع", "صنع", "ت.ا", "DOM", "MFD", "تعبئة", "تعبئة في", "فحص", "تاريخ الفحص", "ت الفحص", "ت. فحص", "ت.فحص", "ت.الفحص"
    )

    private val expKeywords = listOf(
        "expiry", "exp", "ex:", "ex.", "expire", "best before", "e:", "e :", "e.", "exp.", "expiry date", "use by", "date of expiry", "date of expiration", "expiration date", "valid until", "valid till", "exp. date", "exp date",
        "انتهاء", "تاريخ الانتهاء", "تاريخ الإنتهاء", "تاريخ النتهاء", "ت.هـ", "DOE", "EXP", "يستخدم قبل", "ينتهي في", "تاريخ انتهاء", "صالح حتى", "تاريخ الصلاحية", "صلاحية", "ت.انتهاء"
    )

    private val nameKeywords = listOf(
        "product name", "name", "variety", "product", "item", "brand", "crop",
        "اسم المنتج", "المنتج", "الاسم", "صنف", "صنف :", "المادة", "نوع", "اسم الصنف", "ماركة", "المحصول", "اسم الصنف :"
    )

    private val sizeKeywords = listOf(
        "size", "weight", "qty", "quantity", "capacity", "net", "mass", "vol", "w:", "w :", "g.", "net wt", "net weight", "seeds",
        "الحجم", "الوزن", "الكمية", "السعة", "صافي", "الوزن الصافي", "الوزن القائم", "وزن", "الوزن عند التعبئة", "الوزن الصافي عند التعبئة", "الكمية الصافية", "الوزن :", "بذور", "بذرة", "حبة", "üjll"
    )

    private val lotKeywords = listOf(
        "lot", "batch", "b/n", "b/n:", "bn:", "b.n:", "رقم اللوط", "رقم التشغيلة", "رقم", "batch no", "lot no", "لوط", "رقم اللوط :", "رقم اللوط:", "lot number", "انتاج رقم"
    )

    private val validityKeywords = listOf(
        "validity", "period", "duration", "الصلاحية", "صالح لمدة", "صلاحية", "مدة الصلاحية", "فترة الصلاحية", "تاريخ الصلاحية",
        "سنة", "سنتين", "سنتان", "عام", "عامان", "عامين", "أعوام", "سنوات", "شهر", "شهور", "أشهر", "شهران", "شهرين"
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
        Regex("""\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[.\s/-]+\d{1,2}t?h?,?\s+\d{4}\b""", RegexOption.IGNORE_CASE),
        Regex("""\b\d{1,2}[.\s/-]+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[.\s/-]+\d{4}\b""", RegexOption.IGNORE_CASE),
        Regex("""\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[.\s/-]+\d{4}\b""", RegexOption.IGNORE_CASE),
        
        // Arabic Textual Dates
        Regex("""\b(يناير|فبراير|مارس|أبريل|مايو|يونيو|يوليو|أغسطس|سبتمبر|أكتوبر|نوفمبر|ديسمبر)[.\s/-]+\d{4}\b"""),
        Regex("""\b\d{1,2}[.\s/-]+(يناير|فبراير|مارس|أبريل|مايو|يونيو|يوليو|أغسطس|سبتمبر|أكتوبر|نوفمبر|ديسمبر)[.\s/-]+\d{4}\b"""),
        
        // No-separator formats (Stricter validation required)
        Regex("""\b\d{8}\b""") // YYYYMMDD
    )

    private val unitRegex = Regex("""(\d+[,.]?\d*)\s*(kg|g|mg|gr|ks|l|ml|liter|litres|gram|kilogram|kgm|غم|غرام|مل|ملي|ك|كيلو|كيلوجرام|كيلو جرام|جرام|جم|كجم|seeds|بذرة|بذور|pcs|piece)""", RegexOption.IGNORE_CASE)

    private val massUnits = listOf("kg", "g", "mg", "gr", "ks", "l", "ml", "liter", "litres", "gram", "kilogram", "kgm", "غم", "غرام", "مل", "ملي", "ك", "كيلو", "كيلوجرام", "كيلو جرام", "جرام", "جم", "كجم")
    private val countUnits = listOf("seeds", "بذرة", "بذور", "حبة", "pcs", "piece")

    fun cleanProductCode(code: String): String {
        var c = code.trim()
        
        // Remove AIM Symbology Identifiers (e.g., ]C1, ]E0, ]d2, etc.)
        // These are always 3 characters starting with ]
        val aimRegex = Regex("""\][A-Za-z][0-9]""")
        c = c.replace(aimRegex, "")

        // Handle common OCR/Barcode misinterpretations of the GS1-128 identifier
        // and bracketed versions that sometimes appear.
        val technicalPrefixes = listOf(
            "[C1", "]C1", "|C1", "1C1", "(01)", "01)", "]C1 ", "[C1 "
        )
        
        var foundPrefix = true
        while (foundPrefix) {
            foundPrefix = false
            for (prefix in technicalPrefixes) {
                if (c.startsWith(prefix, ignoreCase = true)) {
                    c = c.substring(prefix.length).trim()
                    foundPrefix = true
                }
            }
            // Also handle if it starts with ']' and then some letters/numbers
            if (c.startsWith("]")) {
                c = c.substring(1).trim()
                foundPrefix = true
            }
        }
        
        // Remove any leading zeros that are often part of GS1 AI(01) but not wanted in the code
        // Only if the code is long (GTIN-14 style)
        if (c.length > 10 && c.startsWith("00")) {
            c = c.substring(2)
        } else if (c.length > 10 && c.startsWith("0")) {
            // Optional: some users want the leading zero, some don't.
        }

        return c.trim().removePrefix(":").trim()
    }

    fun parseRaw(rawText: String): Product {
        Log.d("TextParser", "Parsing raw text: $rawText")
        val dateElements = mutableListOf<String>()
        var foundQuantity = "1"
        var foundSize: String? = null
        var foundProductCode: String = ""
        
        val normalizedRaw = normalizeDigits(rawText)
        
        // 1. First Pass: Look for specific patterns
        for (key in sizeKeywords) {
            val keyIdx = normalizedRaw.indexOf(key, ignoreCase = true)
            if (keyIdx != -1) {
                val searchArea = normalizedRaw.substring(keyIdx + key.length).take(30).trim(':').trim()
                unitRegex.find(searchArea)?.let { match ->
                    val value = match.value
                    val unit = match.groupValues[2].lowercase()
                    if (massUnits.any { unit == it }) {
                        foundSize = value
                    } else if (countUnits.any { unit == it }) {
                        foundQuantity = match.groupValues[1]
                    }
                }
            }
        }

        // 2. Second Pass: Generic search
        if (foundSize == null || foundQuantity == "1") {
            unitRegex.findAll(normalizedRaw).forEach { match ->
                val value = match.value
                val unit = match.groupValues[2].lowercase()
                if (foundSize == null && massUnits.any { unit == it }) {
                    foundSize = value
                } else if (foundQuantity == "1" && countUnits.any { unit == it }) {
                    foundQuantity = match.groupValues[1]
                }
            }
        }
        
        // Look for Product Code/Batch
        for (key in lotKeywords) {
            if (normalizedRaw.lowercase().contains(key.lowercase())) {
                val value = normalizedRaw.lowercase().substringAfter(key.lowercase()).trim(':').trim()
                val codeLine = value.substringBefore("\n").trim()
                if (codeLine.length >= 2) foundProductCode = cleanProductCode(codeLine)
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

        // Pass 1: Textual dates from original text (safe normalization of digits only)
        val safeNormalized = normalizeDigits(text)
        for (pattern in datePatterns) {
            pattern.findAll(safeNormalized).forEach { match ->
                val raw = match.value.trim()
                if (raw.any { it.isLetter() }) {
                    convertTextDateToNumeric(raw)?.let { found.add(it) }
                }
            }
        }

        // Pass 2: Numeric dates from aggressively normalized text
        val normalized = normalizeDigitsForDates(text)
        for (pattern in datePatterns) {
            pattern.findAll(normalized).forEach { match ->
                var raw = match.value.trim()
                if (!raw.any { it.isLetter() }) {
                    // Check if it's potentially a lot number disguised as a date (e.g., 101944)
                    // If it's 6 digits, we now only allow it if it has separators (Handled by removing \b\d{6}\b)
                    
                    raw = raw.replace(" ", "")
                    // Heuristic for no-separator dates (8-digit only)
                    if (raw.length == 8 && !raw.contains("/") && !raw.contains(".") && !raw.contains("-")) {
                        val m1 = try { raw.substring(0, 2).toInt() } catch (e: Exception) { 0 }
                        val m2 = try { raw.substring(2, 4).toInt() } catch (e: Exception) { 0 }
                        if (m1 in 1..12 || m2 in 1..12) {
                            raw = "${raw.substring(0, 2)}/${raw.substring(2, 4)}/${raw.substring(4)}"
                        } else return@forEach
                    }
                    val dateVal = raw.replace(".", "/").replace("-", "/")
                    if (isValidDate(dateVal)) found.add(dateVal)
                }
            }
        }
        return found.distinct()
    }

    private fun extractSmartNameFromRaw(rawText: String): String {
        val lines = rawText.lines().filter { it.isNotBlank() }
        val noise = Regex("""(?i)batch|lot|weight|net|tel|phone|price|egp|le|pcs|size|qty|p:|e:|b/n|\d|انتاج|فحص|تاريخ|exp|mfg|prod|date|expiry|الصافي|وزن|seeds|بذور|بذرة""")
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
        
        // 1. Prioritize text following keywords
        for (block in mlText.textBlocks) {
            val blockText = normalizeDigits(block.text)
            for (key in sizeKeywords) {
                if (blockText.contains(key, ignoreCase = true)) {
                    val afterKey = blockText.substringAfter(key).trim(':').trim()
                    unitRegex.find(afterKey)?.let { match ->
                        val value = match.value
                        val unit = match.groupValues[2].lowercase()
                        
                        if (massUnits.any { unit == it }) {
                            foundSize = value
                        } else if (countUnits.any { unit == it }) {
                            foundQuantity = match.groupValues[1]
                        }
                    }
                }
            }
        }

        // 2. Fallback to generic pattern search for anything missing
        if (foundSize == null || foundQuantity == "1") {
            unitRegex.findAll(fullText).forEach { match ->
                val value = match.value
                val unit = match.groupValues[2].lowercase()
                
                if (foundSize == null && massUnits.any { unit == it }) {
                    foundSize = value
                } else if (foundQuantity == "1" && countUnits.any { unit == it }) {
                    foundQuantity = match.groupValues[1]
                }
            }
        }

        for (block in mlText.textBlocks) {
            val normalizedBlockText = normalizeDigits(block.text).lowercase()
            for (key in lotKeywords) {
                if (normalizedBlockText.contains(key.lowercase())) {
                    val value = normalizedBlockText.substringAfter(key.lowercase()).trim(':').trim()
                    val codeLine = value.substringBefore("\n").trim()
                    if (codeLine.length >= 2) foundProductCode = cleanProductCode(codeLine)
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

        val uniqueDateElements = dateElements.distinctBy { convertToSortable(it.value) }
        var finalMfg: String? = null
        var finalExp: String? = null
        var mfgBox: String? = null
        var expBox: String? = null

        for (dateElem in uniqueDateElements) {
            val dateBox = dateElem.line.boundingBox ?: continue
            var bestType = 0 
            var minDist = 1000f // Increased distance for complex labels
            
            for (block in mlText.textBlocks) {
                val bBox = block.boundingBox ?: continue
                val bText = block.text.lowercase()
                
                // Table-friendly distance: Heavily prioritize vertical proximity (same row)
                // Columns are usually further apart horizontally than rows are vertically.
                val yDist = abs(bBox.centerY() - dateBox.centerY()).toFloat()
                val xDist = abs(bBox.left - dateBox.left).toFloat()
                val dist = yDist * 2.5f + xDist * 0.1f // Favor vertical alignment heavily
                
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

        val allUniqueDatesStrings = uniqueDateElements.map { it.value }.distinct()
        if (allUniqueDatesStrings.size >= 2) {
            val sorted = sortDateStrings(allUniqueDatesStrings)
            if (finalMfg == null && finalExp == null) {
                finalMfg = sorted.first(); finalExp = sorted.last()
            } else if (finalMfg != null && finalExp == null) {
                finalExp = allUniqueDatesStrings.find { it != finalMfg }
            } else if (finalExp != null && finalMfg == null) {
                finalMfg = allUniqueDatesStrings.find { it != finalExp }
            }
            if (finalMfg != null && finalExp != null && isSecondBeforeFirst(finalExp, finalMfg)) {
                val t = finalMfg; finalMfg = finalExp; finalExp = t
            }
        } else if (allUniqueDatesStrings.size == 1) {
            if (finalMfg != null || foundValidityText.isNotEmpty()) {
                finalMfg = allUniqueDatesStrings.first()
                finalExp = calculateExpiry(finalMfg, foundValidityText)
            } else {
                finalExp = allUniqueDatesStrings.first()
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
        var y = 0; var m = 0
        val low = validity?.lowercase() ?: ""
        
        // 2 Years (dual form) with fuzzy Arabic matching
        if (low.contains("سنتين") || low.contains("سنتان") || low.contains("عامان") || low.contains("عامين") || 
            low.contains("سنه تين") || low.contains("2 years") || low.contains("2 year")) {
            y = 2
        } 
        // X Years
        else if (low.contains("سنة") || low.contains("عام") || low.contains("أعوام") || low.contains("سنوات") || low.contains("year")) {
            val match = Regex("""(\d+)""").find(low)
            y = match?.groupValues?.get(1)?.toIntOrNull() ?: 1
        }
        
        // 2 Months (dual form)
        if (low.contains("شهران") || low.contains("شهرين") || low.contains("2 months") || low.contains("2 month")) {
            m = 2
        }
        // X Months
        else if (low.contains("شهر") || low.contains("شهور") || low.contains("أشهر") || low.contains("month")) {
            val match = Regex("""(\d+)""").find(low)
            m = match?.groupValues?.get(1)?.toIntOrNull() ?: 0
            if (y == 0 && m == 0) m = 1 
        }

        if (y == 0 && m == 0) y = 2 // Reverted to default 2 years if context was matched

        return addTimeToDate(base, y, m)
    }

    private fun addTimeToDate(date: String, years: Int, months: Int): String? {
        val parts = date.split('/')
        return try {
            val v1 = parts[0].toInt()
            val v2 = parts[1].toInt()
            val v3 = if (parts.size > 2) parts[2].toInt() else 1

            var y: Int; var m: Int; var d: Int
            if (v1 > 100) { // YYYY/MM/DD or YYYY/MM
                y = v1; m = v2; d = v3
            } else if (parts.size == 2) { // MM/YYYY or MM/YY
                y = if (v2 < 100) 2000 + v2 else v2; m = v1; d = 1
            } else { // DD/MM/YYYY or DD/MM/YY
                val yearPart = parts.last().toInt()
                y = if (yearPart < 100) 2000 + yearPart else yearPart; m = v2; d = v1
            }

            m += months; y += years + (m - 1) / 12; m = (m - 1) % 12 + 1
            "${d.toString().padStart(2,'0')}/${m.toString().padStart(2,'0')}/$y"
        } catch (e: Exception) { null }
    }

    private fun extractSmartName(mlText: Text, lot: String): String {
        val candidates = mutableListOf<NameCandidate>()
        // Improved noise filter to exclude registration numbers and common non-name terms
        val noise = Regex("""(?i)batch|lot|weight|net|tel|phone|price|egp|le|pcs|size|qty|p:|e:|b/n|انتاج|فحص|تاريخ|exp|mfg|prod|date|expiry|الصافي|وزن|تسجيل|رقم|s000|\b\d{4,}\b|الوزن|جرام|gram|üjll|بذور|seeds|بذرة|بذره""")
        
        for (block in mlText.textBlocks) {
            val originalText = block.text.trim().replace("\n", " ")
            val bBox = block.boundingBox ?: continue
            
            // If the text contains a size keyword, it's likely not the name
            if (sizeKeywords.any { originalText.contains(it, ignoreCase = true) }) continue
            
            // Priority 1: Text following an Arabic or English name keyword
            for (key in nameKeywords) {
                if (originalText.contains(key)) {
                    val afterKey = originalText.substringAfter(key).trim(':').trim()
                    if (afterKey.length > 2 && !noise.containsMatchIn(afterKey)) {
                        return afterKey.substringBefore("EXP").substringBefore("MFG").trim()
                    }
                }
            }

            val text = originalText.substringBefore("Prod").substringBefore("EXP").trim()
            if (text.length < 3 || noise.containsMatchIn(text)) continue
            
            // Score based on text size (larger is better for titles) and position (higher is better)
            // Penalty for being too low on the page
            val yFactor = 1.0 - (bBox.top.toDouble() / 1000.0)
            val score = bBox.height().toDouble() * 2.0 * yFactor
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
        val m = mapOf('٠' to '0', '١' to '1', '٢' to '2', '٣' to '3', '٤' to '4', '٥' to '5', '٦' to '6', '٧' to '7', '٨' to '8', '٩' to '9')
        return input.map { m[it] ?: it }.joinToString("")
    }

    private fun normalizeDigitsForDates(input: String): String {
        val m = mapOf('٠' to '0', '١' to '1', '٢' to '2', '٣' to '3', '٤' to '4', '٥' to '5', '٦' to '6', '٧' to '7', '٨' to '8', '٩' to '9', 'o' to '0', 'O' to '0', 'l' to '1', 'I' to '1', 's' to '5', 'S' to '5', 'b' to '6', 'z' to '2')
        return input.map { m[it] ?: it }.joinToString("")
    }

    private fun isValidDate(date: String): Boolean {
        val p = date.split('/')
        if (p.size < 2) return false
        return try {
            val v1 = p[0].toInt()
            val v2 = p.last().toInt()
            // Identify year: either 4 digits or > 31
            val year = if (v1 > 100) v1 else if (v2 > 100) v2 else if (v1 > 31) 2000 + v1 else 2000 + v2
            val month = if (v1 > 100) p[1].toInt() else if (v2 > 100) v1 else if (v1 > 12) v2 else v1
            (month in 1..12) && (year in 2020..2045)
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
            val v1 = p[0].toInt()
            val v2 = p.last().toInt()
            
            if (p.size == 2) {
                if (v1 > 100) { y = v1.toString(); m = v2.toString() }
                else if (v2 > 100) { y = v2.toString(); m = v1.toString() }
                else if (v1 > 12) { y = "20$v1"; m = v2.toString() }
                else { y = "20$v2"; m = v1.toString() }
            } else if (p.size == 3) {
                if (v1 > 100) { y = v1.toString(); m = p[1]; d = p[2] }
                else { y = v2.toString(); m = p[1]; d = v1.toString() }
            }
            if (y.length == 2) y = "20$y"
        } catch (e: Exception) {}
        return y.padStart(4,'0') + m.padStart(2,'0') + d.padStart(2,'0')
    }

    private fun sortDateStrings(dates: List<String>) = dates.sortedBy { convertToSortable(it) }
}
