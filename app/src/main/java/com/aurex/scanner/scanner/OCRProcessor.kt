package com.aurex.scanner.scanner

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import com.aurex.scanner.data.Product
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

object OCRProcessor {

    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    fun init(context: Context) {
        // Any initialization if needed
    }

    fun process(context: Context, uri: Uri, callback: (Product) -> Unit) {
        val image = try {
            InputImage.fromFilePath(context, uri)
        } catch (e: Exception) {
            Log.e("OCRProcessor", "Error loading image from URI: $uri", e)
            return
        }

        // We still need the bitmap for OpenAI fallback
        val bitmap = try {
            val inputStream = context.contentResolver.openInputStream(uri)
            BitmapFactory.decodeStream(inputStream)
        } catch (e: Exception) {
            Log.e("OCRProcessor", "Error decoding bitmap for OpenAI", e)
            null
        }
        
        Log.d("OCRProcessor", "Processing image: $uri")
        
        // 1. Try Cloud Vision API first for high-quality Arabic/English extraction
        if (bitmap != null) {
            Log.d("OCRProcessor", "Starting Cloud Vision processing...")
            CloudVisionHelper.extractText(bitmap) { cloudText ->
                if (!cloudText.isNullOrBlank()) {
                    Log.d("OCRProcessor", "Cloud Vision success, parsing text: ${cloudText.take(100)}...")
                    val product = TextParser.parseRaw(cloudText)
                    if (product.mfgDate != null || product.expDate != null) {
                        Log.d("OCRProcessor", "Parsed from Cloud Vision: $product")
                        callback(product)
                        return@extractText
                    }
                }
                
                // 2. Fallback to OpenAI if Cloud Vision fails or doesn't find dates
                Log.d("OCRProcessor", "Cloud Vision insufficient or failed, trying OpenAI...")
                OpenAIHelper.processImage(bitmap) { openAIProduct ->
                    if (openAIProduct != null && (openAIProduct.mfgDate != null || openAIProduct.expDate != null)) {
                        Log.d("OCRProcessor", "OpenAI success: $openAIProduct")
                        callback(openAIProduct)
                    } else {
                        Log.d("OCRProcessor", "OpenAI failed or no dates, trying ML Kit...")
                        processWithMLKit(image, bitmap, callback)
                    }
                }
            }
        } else {
            Log.d("OCRProcessor", "No bitmap, falling back to ML Kit...")
            processWithMLKit(image, null, callback)
        }
    }

    private fun processWithMLKit(image: InputImage, bitmap: Bitmap?, callback: (Product) -> Unit) {
        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                Log.d("OCRProcessor", "ML Kit detected text: ${visionText.text.take(200)}")
                val mlProduct = TextParser.parse(visionText)
                callback(mlProduct)
            }
            .addOnFailureListener { e ->
                Log.e("OCRProcessor", "ML Kit Error", e)
                callback(Product(productCode = "", name = "Unknown Product", mfgDate = null, expDate = null))
            }
    }
}
