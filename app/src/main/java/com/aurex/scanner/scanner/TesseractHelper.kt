package com.aurex.scanner.scanner

import android.content.Context
import android.graphics.Bitmap
import com.googlecode.tesseract.android.TessBaseAPI
import java.io.File
import java.io.FileOutputStream

object TesseractHelper {

    private const val TESS_DATA = "tessdata"
    private val LANGUAGES = listOf("ara", "eng")

    fun init(context: Context) {
        val tessDir = File(context.filesDir, TESS_DATA)
        if (!tessDir.exists()) tessDir.mkdirs()

        LANGUAGES.forEach { lang ->
            val targetFile = File(tessDir, "$lang.traineddata")
            if (!targetFile.exists()) {
                copyAsset(context, "$TESS_DATA/$lang.traineddata", targetFile)
            }
        }
    }

    fun recognizeText(context: Context, bitmap: Bitmap): String {
        val tess = TessBaseAPI()
        return try {
            val dataPath = context.filesDir.absolutePath
            if (tess.init(dataPath, "ara+eng")) {
                tess.setImage(bitmap)
                tess.utF8Text ?: ""
            } else {
                ""
            }
        } catch (e: Exception) {
            e.printStackTrace()
            ""
        } finally {
            tess.recycle()
        }
    }

    private fun copyAsset(context: Context, assetPath: String, targetFile: File) {
        try {
            context.assets.open(assetPath).use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
