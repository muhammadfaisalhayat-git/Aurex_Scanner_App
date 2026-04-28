package com.aurex.scanner.scanner

import android.graphics.Bitmap
import android.util.Base64
import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit

object CloudVisionHelper {
    private const val API_KEY = "AIzaSyAmReqYoqeNAyUUYXzaQu7wO4-jWgs2rYg"
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()
    private val gson = Gson()

    fun extractText(bitmap: Bitmap, callback: (String?) -> Unit) {
        val base64Image = encodeImage(bitmap)

        val requestJson = JsonObject().apply {
            val requests = JsonArray().apply {
                add(JsonObject().apply {
                    add("image", JsonObject().apply {
                        addProperty("content", base64Image)
                    })
                    add("features", JsonArray().apply {
                        add(JsonObject().apply {
                            addProperty("type", "TEXT_DETECTION")
                        })
                    })
                    add("imageContext", JsonObject().apply {
                        add("languageHints", JsonArray().apply {
                            add("ar")
                            add("en")
                        })
                    })
                })
            }
            add("requests", requests)
        }

        val body = requestJson.toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url("https://vision.googleapis.com/v1/images:annotate?key=$API_KEY")
            .post(body)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("CloudVisionHelper", "Request failed", e)
                callback(null)
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (!it.isSuccessful) {
                        Log.e("CloudVisionHelper", "Error: ${it.code} ${it.message}")
                        callback(null)
                        return
                    }

                    val responseBody = it.body?.string() ?: ""
                    try {
                        val jsonResponse = gson.fromJson(responseBody, JsonObject::class.java)
                        val text = jsonResponse.getAsJsonArray("responses")
                            .get(0).asJsonObject
                            .getAsJsonObject("fullTextAnnotation")
                            ?.get("text")?.asString
                        
                        callback(text)
                    } catch (e: Exception) {
                        Log.e("CloudVisionHelper", "Parsing error", e)
                        callback(null)
                    }
                }
            }
        })
    }

    private fun encodeImage(bitmap: Bitmap): String {
        val byteArrayOutputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, byteArrayOutputStream)
        val byteArray = byteArrayOutputStream.toByteArray()
        return Base64.encodeToString(byteArray, Base64.NO_WRAP)
    }
}
