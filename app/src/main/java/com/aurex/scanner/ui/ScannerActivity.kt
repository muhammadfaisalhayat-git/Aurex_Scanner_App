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
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.Rect
import android.view.ScaleGestureDetector
import android.view.MotionEvent
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
    private lateinit var galleryBtn: ImageButton
    private lateinit var historyBtn: ImageButton
    private lateinit var camera: androidx.camera.core.Camera
    private lateinit var imageCapture: ImageCapture
    private lateinit var imageAnalysis: ImageAnalysis
    private lateinit var cameraExecutor: ExecutorService
    private lateinit var overlay: ScannerOverlayView
    private lateinit var processingLayout: android.view.View
    private lateinit var controlsLayout: android.view.View
    private lateinit var ivCapturedPreview: android.widget.ImageView
    private lateinit var processingOverlay: com.aurex.scanner.ScannerOverlayView

    private lateinit var scaleGestureDetector: ScaleGestureDetector

    private val shutterSound = MediaActionSound()

    // Use Latin Recognizer for live feedback
    private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    private var isFlashOn = false
    private var detectedBarcode: String? = null
    private var lastDetectionTime = 0L

    private var isSingleScanMode = false
    private var scanTarget: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        isSingleScanMode = intent.getBooleanExtra("SINGLE_SCAN_MODE", false)
        scanTarget = intent.getStringExtra("SCAN_TARGET")

        // Make full screen
        window.decorView.systemUiVisibility = (android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
        supportActionBar?.hide()

        setContentView(R.layout.activity_scanner)

        previewView = findViewById(R.id.previewView)
        captureBtn = findViewById(R.id.btnCapture)
        flashBtn = findViewById(R.id.btnFlash)
        galleryBtn = findViewById(R.id.btnGallery)
        historyBtn = findViewById(R.id.btnHistory)
        overlay = findViewById(R.id.overlay)
        processingLayout = findViewById(R.id.processingLayout)
        controlsLayout = findViewById(R.id.controlsLayout)
        ivCapturedPreview = findViewById(R.id.ivCapturedPreview)
        processingOverlay = findViewById(R.id.processingOverlay)

        setupZoom()

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
        galleryBtn.setOnClickListener { pickFromGallery() }
        historyBtn.setOnClickListener {
            startActivity(Intent(this, ProductListActivity::class.java))
        }
    }

    override fun onResume() {
        super.onResume()
        resetScannerUI()
    }

    private fun resetScannerUI() {
        runOnUiThread {
            processingLayout.visibility = android.view.View.GONE
            controlsLayout.visibility = android.view.View.VISIBLE
            ivCapturedPreview.setImageDrawable(null)
            processingOverlay.setStaticImageMode(false)
            detectedBarcode = null
            lastDetectionTime = 0L
        }
    }

    private fun setupZoom() {
        val listener = object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                if (::camera.isInitialized) {
                    val currentZoomRatio = camera.cameraInfo.zoomState.value?.zoomRatio ?: 1f
                    val delta = detector.scaleFactor
                    camera.cameraControl.setZoomRatio(currentZoomRatio * delta)
                }
                return true
            }
        }
        scaleGestureDetector = ScaleGestureDetector(this, listener)

        previewView.setOnTouchListener { view, event ->
            scaleGestureDetector.onTouchEvent(event)
            if (event.action == MotionEvent.ACTION_UP) {
                view.performClick()
            }
            true
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
                                // Strip common technical prefixes like ]C1 or [C1 via TextParser
                                val raw = barcode.rawValue ?: ""
                                if (raw.isNotEmpty()) {
                                    if (detectedBarcode == null) {
                                        // Play beep for first detection in live view
                                        try {
                                            val toneG = android.media.ToneGenerator(android.media.AudioManager.STREAM_NOTIFICATION, 100)
                                            toneG.startTone(android.media.ToneGenerator.TONE_PROP_BEEP, 100)
                                        } catch (e: Exception) {}
                                    }
                                    detectedBarcode = TextParser.cleanProductCode(raw)
                                    Log.d("ScannerActivity", "Detected Barcode: $detectedBarcode (raw: $raw)")
                                }
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
        if (!::imageCapture.isInitialized) return

        // Force target rotation to match current display
        try {
            val rotation = previewView.display.rotation
            imageCapture.targetRotation = rotation
        } catch (e: Exception) {
            Log.e("ScannerActivity", "Failed to set target rotation", e)
        }

        shutterSound.play(MediaActionSound.SHUTTER_CLICK)

        processingLayout.visibility = android.view.View.VISIBLE
        controlsLayout.visibility = android.view.View.GONE

        val photoFile = File(externalCacheDir, "scan.jpg")
        val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()

        imageCapture.takePicture(
            outputOptions,
            cameraExecutor,
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    // 1. Fix rotation immediately on the background thread
                    // We also pass the rotation degrees from the metadata if available
                    fixImageRotation(photoFile)
                    
                    val bitmap = BitmapFactory.decodeFile(photoFile.absolutePath)
                    
                    runOnUiThread {
                        if (bitmap != null) {
                            ivCapturedPreview.setImageBitmap(bitmap)
                            processingOverlay.setImageSize(bitmap.width, bitmap.height)
                            
                            // 2. Start text detection for the animation
                            getDetectedTextBlocks(photoFile)
                        }
                    }
                    processImage(photoFile)
                }

                override fun onError(exc: ImageCaptureException) {
                    resetScannerUI()
                    Toast.makeText(this@ScannerActivity, "Capture failed", Toast.LENGTH_SHORT).show()
                }
            }
        )
    }

    private fun getDetectedTextBlocks(file: File) {
        // We use ML Kit to quickly get text blocks for highlighting
        try {
            val image = InputImage.fromFilePath(this, Uri.fromFile(file))
            textRecognizer.process(image).addOnSuccessListener { visionText ->
                // Filter blocks to focus on relevant text (avoiding tiny background noise)
                val blocks = visionText.textBlocks.filter { block ->
                    val t = block.text
                    t.length >= 3 && (t.any { it.isDigit() } || t.length > 5)
                }.mapNotNull { it.boundingBox }

                processingOverlay.setStaticImageMode(true, blocks)
            }
        } catch (e: Exception) {
            Log.e("ScannerActivity", "Error detecting blocks for overlay", e)
        }
    }

    private fun processImage(file: File) {
        // Rotation is already fixed in onImageSaved

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
            
            // If OCR didn't find a product code but the barcode scanner did, use that
            if (finalProduct.productCode.isEmpty() && detectedBarcode != null) {
                finalProduct = finalProduct.copy(productCode = detectedBarcode!!)
            }

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
                resetScannerUI()
            }
            .setCancelable(false)
            .show()
    }

    private fun navigateToResult(product: com.aurex.scanner.data.Product) {
        if (isSingleScanMode) {
            val resultIntent = Intent()
            val resultValue = when (scanTarget) {
                "NAME" -> product.name
                "CODE" -> product.productCode
                "SIZE" -> product.size
                "MFG" -> product.mfgDate
                "EXP" -> product.expDate
                else -> product.name
            }
            resultIntent.putExtra("SCAN_RESULT", resultValue)
            setResult(RESULT_OK, resultIntent)
            finish()
        } else {
            val intent = Intent(this, ResultActivity::class.java)
            intent.putExtra("data", product)
            startActivity(intent)
        }
    }

    private fun fixImageRotation(file: File) {
        try {
            val exif = ExifInterface(file.absolutePath)
            var orientation = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_UNDEFINED
            )

            val bitmap = BitmapFactory.decodeFile(file.absolutePath) ?: return

            // If EXIF orientation is missing but the image is wider than tall, 
            // and we are in portrait mode, it likely needs a 90-degree rotation.
            if (orientation == ExifInterface.ORIENTATION_UNDEFINED || orientation == ExifInterface.ORIENTATION_NORMAL) {
                if (bitmap.width > bitmap.height) {
                    orientation = ExifInterface.ORIENTATION_ROTATE_90
                }
            }

            if (orientation == ExifInterface.ORIENTATION_NORMAL || orientation == ExifInterface.ORIENTATION_UNDEFINED) {
                // If it's already vertical or we can't determine, just ensure it's saved at high quality
                return
            }

            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            }

            val rotatedBitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            
            // 3. Crop to the frame shown in the overlay
            // Overlay uses: left=10%, top=20%, right=90%, bottom=80%
            val cropLeft = (rotatedBitmap.width * 0.10f).toInt()
            val cropTop = (rotatedBitmap.height * 0.20f).toInt()
            val cropWidth = (rotatedBitmap.width * 0.80f).toInt()
            val cropHeight = (rotatedBitmap.height * 0.60f).toInt()
            
            val croppedBitmap = Bitmap.createBitmap(rotatedBitmap, cropLeft, cropTop, cropWidth, cropHeight)
            
            FileOutputStream(file).use { out ->
                croppedBitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
            }
            
            // Reset orientation in EXIF to normal so it's not rotated twice
            val newExif = ExifInterface(file.absolutePath)
            newExif.setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
            newExif.saveAttributes()

            if (bitmap != rotatedBitmap) {
                bitmap.recycle()
            }
            rotatedBitmap.recycle()
            croppedBitmap.recycle()
        } catch (e: Exception) {
            Log.e("ScannerActivity", "Error fixing rotation and cropping", e)
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

    private fun pickFromGallery() {
        val intent = Intent(Intent.ACTION_PICK)
        intent.type = "image/*"
        startActivityForResult(intent, 2001)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode == RESULT_OK) {
            when (requestCode) {
                2001 -> {
                    val selectedImageUri = data?.data ?: return
                    handleGalleryImage(selectedImageUri)
                }
            }
        }
    }

    private fun handleGalleryImage(uri: Uri) {
        processingLayout.visibility = android.view.View.VISIBLE
        controlsLayout.visibility = android.view.View.GONE

        val photoFile = File(externalCacheDir, "gallery_pick.jpg")
        
        try {
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(photoFile).use { output ->
                    input.copyTo(output)
                }
            }
            
            // Fix rotation if needed (gallery images often have EXIF issues)
            fixImageRotation(photoFile)
            
            val bitmap = BitmapFactory.decodeFile(photoFile.absolutePath)
            if (bitmap != null) {
                ivCapturedPreview.setImageBitmap(bitmap)
                processingOverlay.setImageSize(bitmap.width, bitmap.height)
                getDetectedTextBlocks(photoFile)
            }
            
            processImage(photoFile)
            
        } catch (e: Exception) {
            Log.e("ScannerActivity", "Error handling gallery image", e)
            resetScannerUI()
            Toast.makeText(this, "Failed to load image", Toast.LENGTH_SHORT).show()
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

        // Correctly handle coordinate mapping for CENTER_CROP (default for PreviewView)
        val isRotated = imageProxy.imageInfo.rotationDegrees % 180 != 0
        val imageWidth = if (isRotated) imageProxy.height.toFloat() else imageProxy.width.toFloat()
        val imageHeight = if (isRotated) imageProxy.width.toFloat() else imageProxy.height.toFloat()

        val scale = Math.max(previewView.width.toFloat() / imageWidth, previewView.height.toFloat() / imageHeight)
        val offsetX = (previewView.width - imageWidth * scale) / 2f
        val offsetY = (previewView.height - imageHeight * scale) / 2f

        return Rect(
            (left * scale + offsetX).toInt(),
            (top * scale + offsetY).toInt(),
            (right * scale + offsetX).toInt(),
            (bottom * scale + offsetY).toInt()
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }
}
