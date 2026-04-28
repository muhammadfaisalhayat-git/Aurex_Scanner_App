package com.aurex.scanner.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaActionSound
import android.net.Uri
import android.os.*
import android.util.Log
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
import com.aurex.scanner.ScannerOverlayView
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.text.Text
import androidx.exifinterface.media.ExifInterface
import android.graphics.Matrix
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Rect
import androidx.appcompat.app.AlertDialog
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

@ExperimentalGetImage
class ScannerActivity : BaseActivity() {

    private lateinit var previewView: PreviewView
    private lateinit var captureBtn: ImageButton
    private lateinit var flashBtn: ImageButton
    private lateinit var historyBtn: ImageButton
    private lateinit var camera: Camera
    private lateinit var imageCapture: ImageCapture
    private lateinit var imageAnalysis: ImageAnalysis
    private lateinit var cameraExecutor: ExecutorService
    private lateinit var overlay: ScannerOverlayView

    private val shutterSound = MediaActionSound()

    // Use Latin Recognizer for live feedback
    private val textRecognizer = TextRecognition.getClient(
        TextRecognizerOptions.DEFAULT_OPTIONS
    )

    private var isFlashOn = false
    private var detectedBarcode: String? = null
    private var lastDetectionTime = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make full screen
        window.decorView.systemUiVisibility = (android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
        supportActionBar?.hide()

        setContentView(R.layout.activity_scanner)

        previewView = findViewById(R.id.previewView)
        captureBtn = findViewById(R.id.btnCapture)
        flashBtn = findViewById(R.id.btnFlash)
        historyBtn = findViewById(R.id.btnHistory)
        overlay = findViewById(R.id.overlay)

        cameraExecutor = Executors.newSingleThreadExecutor()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 100)
        }

        shutterSound.load(MediaActionSound.SHUTTER_CLICK)
        shutterSound.load(MediaActionSound.FOCUS_COMPLETE)

        captureBtn.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
            takePhoto()
        }
        flashBtn.setOnClickListener { toggleFlash() }
        historyBtn.setOnClickListener {
            startActivity(Intent(this, ProductListActivity::class.java))
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            val preview = Preview.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                .build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }

            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                .build()

            imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                .build()

            val barcodeScanner = BarcodeScanning.getClient()

            imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                val mediaImage = imageProxy.image

                if (mediaImage != null) {
                    val image = InputImage.fromMediaImage(
                        mediaImage,
                        imageProxy.imageInfo.rotationDegrees
                    )

                    // ✅ OCR
                    textRecognizer.process(image)
                        .addOnSuccessListener { visionText: Text ->
                            val product = TextParser.parse(visionText)

                            if (product.mfgDate != null || product.expDate != null) {
                                if (System.currentTimeMillis() - lastDetectionTime > 2000) {
                                    shutterSound.play(MediaActionSound.FOCUS_COMPLETE)
                                    lastDetectionTime = System.currentTimeMillis()
                                }
                            }

                            val mfgRect = product.mfgBox?.let {
                                parseBox(it, imageProxy, previewView)
                            }
                            val expRect = product.expBox?.let {
                                parseBox(it, imageProxy, previewView)
                            }

                            runOnUiThread {
                                overlay.updateBoxes(mfgRect, expRect)
                            }
                        }

                    // ✅ Barcode
                    barcodeScanner.process(image)
                        .addOnSuccessListener { barcodes ->
                            for (barcode in barcodes) {
                                detectedBarcode = barcode.rawValue
                            }
                        }
                        .addOnCompleteListener {
                            imageProxy.close()
                        }

                } else {
                    imageProxy.close()
                }
            }

            try {
                cameraProvider.unbindAll()
                camera = cameraProvider.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    imageCapture,
                    imageAnalysis
                )
            } catch (exc: Exception) {
                Log.e("ScannerActivity", "Use case binding failed", exc)
            }

        }, ContextCompat.getMainExecutor(this))
    }

    private fun takePhoto() {
        shutterSound.play(MediaActionSound.SHUTTER_CLICK)

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
        // 1. Fix rotation
        fixImageRotation(file)

        val permanentFile = File(
            getExternalFilesDir(Environment.DIRECTORY_PICTURES),
            "prod_${System.currentTimeMillis()}.jpg"
        )

        // 2. Compress the image (already oriented correctly)
        // This makes the file smaller for OpenAI and storage
        compressImage(file, permanentFile)

        // 3. Process the compressed/rotated image
        OCRProcessor.process(this, Uri.fromFile(permanentFile)) { product ->
            var finalProduct = product
            if (finalProduct.name == "Unknown Product" || finalProduct.name == "Unknown") {
                if (detectedBarcode != null) {
                    finalProduct.name = "Barcode: $detectedBarcode"
                }
            }

            finalProduct = finalProduct.copy(imagePath = permanentFile.absolutePath)

            runOnUiThread {
                if (TextParser.isExpired(finalProduct.expDate)) {
                    showExpiryWarning(finalProduct)
                } else {
                    navigateToResult(finalProduct)
                }
            }
        }
    }

    private fun showExpiryWarning(product: com.aurex.scanner.data.Product) {
        // Play alert sound for expiry
        try {
            shutterSound.play(MediaActionSound.FOCUS_COMPLETE)
            // Additional beep using ToneGenerator for better visibility
            val toneG = android.media.ToneGenerator(android.media.AudioManager.STREAM_ALARM, 100)
            toneG.startTone(android.media.ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 500)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        AlertDialog.Builder(this)
            .setTitle("⚠️ " + getString(R.string.product_expired))
            .setMessage(getString(R.string.product_expired_msg, product.name, product.expDate))
            .setPositiveButton(getString(R.string.save_anyway)) { _, _ ->
                navigateToResult(product)
            }
            .setNegativeButton(getString(R.string.discard)) { _, _ ->
                // Just go back to scanning
            }
            .setCancelable(false)
            .show()
    }

    private fun navigateToResult(product: com.aurex.scanner.data.Product) {
        val intent = Intent(this, ResultActivity::class.java)
        intent.putExtra("data", product)
        startActivity(intent)
    }

    private fun fixImageRotation(file: File) {
        try {
            val exif = ExifInterface(file.absolutePath)
            val orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            if (orientation == ExifInterface.ORIENTATION_NORMAL || orientation == ExifInterface.ORIENTATION_UNDEFINED) return

            val bitmap = BitmapFactory.decodeFile(file.absolutePath) ?: return
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            }
            
            val rotatedBitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            
            FileOutputStream(file).use { out ->
                rotatedBitmap.compress(Bitmap.CompressFormat.JPEG, 100, out)
            }
            
            // Reset orientation in EXIF
            val newExif = ExifInterface(file.absolutePath)
            newExif.setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
            newExif.saveAttributes()

            bitmap.recycle()
            rotatedBitmap.recycle()
        } catch (e: Exception) {
            Log.e("ScannerActivity", "Error fixing rotation", e)
        }
    }

    private fun compressImage(sourceFile: File, destinationFile: File) {
        try {
            val options = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeFile(sourceFile.absolutePath, options)

            // Target max dimension
            val maxSize = 1600
            var sampleSize = 1
            if (options.outHeight > maxSize || options.outWidth > maxSize) {
                sampleSize = if (options.outHeight > options.outWidth) {
                    options.outHeight / maxSize
                } else {
                    options.outWidth / maxSize
                }
            }

            val decodeOptions = BitmapFactory.Options().apply {
                inSampleSize = sampleSize
            }
            val bitmap = BitmapFactory.decodeFile(sourceFile.absolutePath, decodeOptions)

            val out = FileOutputStream(destinationFile)
            // Compress to JPEG with 70% quality
            bitmap.compress(Bitmap.CompressFormat.JPEG, 70, out)
            out.flush()
            out.close()
            bitmap.recycle()
        } catch (e: Exception) {
            Log.e("ScannerActivity", "Error compressing image", e)
            sourceFile.copyTo(destinationFile, overwrite = true)
        }
    }

    private fun toggleFlash() {
        if (::camera.isInitialized) {
            isFlashOn = !isFlashOn
            camera.cameraControl.enableTorch(isFlashOn)
            flashBtn.setImageResource(
                if (isFlashOn) R.drawable.ic_flash_on else R.drawable.ic_flash_off
            )
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            window.decorView.systemUiVisibility = (android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                    or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
        }
    }

    private fun parseBox(boxStr: String, imageProxy: ImageProxy, previewView: PreviewView): Rect {
        val parts = boxStr.split(",")
        val left = parts[0].toFloat()
        val top = parts[1].toFloat()
        val right = parts[2].toFloat()
        val bottom = parts[3].toFloat()

        // Correctly handle coordinate mapping considering image rotation
        // For 90 or 270 degrees, swap width and height
        val isRotated = imageProxy.imageInfo.rotationDegrees % 180 != 0
        val imageWidth = if (isRotated) imageProxy.height.toFloat() else imageProxy.width.toFloat()
        val imageHeight = if (isRotated) imageProxy.width.toFloat() else imageProxy.height.toFloat()

        val scaleX = previewView.width.toFloat() / imageWidth
        val scaleY = previewView.height.toFloat() / imageHeight

        return Rect(
            (left * scaleX).toInt(),
            (top * scaleY).toInt(),
            (right * scaleX).toInt(),
            (bottom * scaleY).toInt()
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }
}
