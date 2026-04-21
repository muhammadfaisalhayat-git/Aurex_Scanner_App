package com.aurex.scanner.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.*
import android.util.Log
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.aurex.scanner.R
import com.aurex.scanner.scanner.OCRProcessor
import com.aurex.scanner.scanner.TextParser
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class ScannerActivity : AppCompatActivity() {

    private lateinit var previewView: PreviewView
    private lateinit var captureBtn: ImageButton
    private lateinit var flashBtn: ImageButton
    private lateinit var camera: Camera
    private lateinit var imageCapture: ImageCapture
    private lateinit var cameraExecutor: ExecutorService

    private var isFlashOn = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Re-using the layout if it exists, or we could build it programmatically 
        // as per the user's snippet. Let's try to stick to the XML for consistency.
        setContentView(R.layout.activity_scanner)

        previewView = findViewById(R.id.previewView)
        captureBtn = findViewById(R.id.btnCapture)
        flashBtn = findViewById(R.id.btnFlash)

        cameraExecutor = Executors.newSingleThreadExecutor()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 100)
        }

        captureBtn.setOnClickListener { takePhoto() }
        flashBtn.setOnClickListener { toggleFlash() }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()

            try {
                cameraProvider.unbindAll()
                camera = cameraProvider.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    imageCapture
                )
            } catch (exc: Exception) {
                Log.e("ScannerActivity", "Use case binding failed", exc)
            }

        }, ContextCompat.getMainExecutor(this))
    }

    private fun takePhoto() {
        val photoFile = File(externalCacheDir, "scan.jpg")
        val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()

        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    processImage(photoFile)
                }

                override fun onError(exc: ImageCaptureException) {
                    Toast.makeText(this@ScannerActivity, "Capture failed", Toast.LENGTH_SHORT).show()
                }
            }
        )
    }

    private fun processImage(file: File) {
        OCRProcessor.process(this, Uri.fromFile(file)) { text ->
            val product = TextParser.parse(text)
            val intent = Intent(this, ResultActivity::class.java)
            intent.putExtra("data", product)
            startActivity(intent)
        }
    }

    private fun toggleFlash() {
        if (::camera.isInitialized) {
            isFlashOn = !isFlashOn
            camera.cameraControl.enableTorch(isFlashOn)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }
}
