package com.aurex.scanner.scanner

import android.graphics.Bitmap
import android.util.Base64
import android.util.Log
import com.aurex.scanner.data.Product
import com.google.gson.Gson
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit

object OpenAIHelper {
    private const val API_KEY = "YOUR_OPENAI_API_KEY_HERE"
    private val client = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()
    private val gson = Gson()

    fun processImage(bitmap: Bitmap, callback: (Product?) -> Unit) {
        val base64Image = encodeImage(bitmap)
        
        val json = """
            {
                "model": "gpt-4o-mini",
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": "Extract product details from this image. The image contains Arabic and English text. Identify: 1. 'productCode': A unique identifier, batch number, serial number, or reference number (often near a barcode or labeled as 'Batch', 'P/N', 'Item Code', 'رقم التشغيلة'). 2. 'name': Primary product name. 3. 'mfgDate': Production/Manufacturing date. 4. 'expDate': Expiry/Best Before date. 5. 'quantity': Weight/Size/Count. Date Formats: Look for DD/MM/YYYY, MM/YYYY, or similar. Convert dates to DD/MM/YYYY format in JSON. Keywords: 'انتاج', 'انتهاء', 'MFG', 'EXP', 'PROD', 'Batch'. If a field is missing, return null. Return ONLY a JSON object."
                            },
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": "data:image/jpeg;base64,$base64Image"
                                }
                            }
                        ]
                    }
                ],
                "response_format": { "type": "json_object" }
            }
        """.trimIndent()

        val body = json.toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url("https://api.openai.com/v1/chat/completions")
            .header("Authorization", "Bearer $API_KEY")
            .post(body)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                e.printStackTrace()
                callback(null)
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (!it.isSuccessful) {
                        println("OpenAI Error: ${it.body?.string()}")
                        callback(null)
                        return
                    }

                    val responseBody = it.body?.string() ?: ""
                    Log.d("OpenAIHelper", "Response: $responseBody")
                    try {
                        val completionResponse = gson.fromJson(responseBody, ChatCompletionResponse::class.java)
                        val content = completionResponse.choices.firstOrNull()?.message?.content ?: ""
                        Log.d("OpenAIHelper", "Content: $content")
                        val product = gson.fromJson(content, Product::class.java)
                        if (product != null) {
                            product.productCode = TextParser.cleanProductCode(product.productCode)
                        }
                        callback(product)
                    } catch (e: Exception) {
                        Log.e("OpenAIHelper", "Parsing error", e)
                        callback(null)
                    }
                }
            }
        })
    }

    private fun encodeImage(bitmap: Bitmap): String {
        val byteArrayOutputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, byteArrayOutputStream)
        val byteArray = byteArrayOutputStream.toByteArray()
        return Base64.encodeToString(byteArray, Base64.NO_WRAP)
    }

    data class ChatCompletionResponse(val choices: List<Choice>)
    data class Choice(val message: Message)
    data class Message(val content: String)
}
