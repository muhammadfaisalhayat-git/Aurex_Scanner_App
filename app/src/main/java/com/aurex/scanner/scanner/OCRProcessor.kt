package com.aurex.scanner.scanner

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

object OCRProcessor {
    fun process(context: Context, uri: Uri, callback: (String) -> Unit) {
        val image = try {
            InputImage.fromFilePath(context, uri)
        } catch (e: Exception) {
            return
        }
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

        recognizer.process(image)
            .addOnSuccessListener { result ->
                callback(result.text)
            }
    }
}
