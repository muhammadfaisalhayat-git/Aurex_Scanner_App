package com.aurex.scanner

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View

class ScannerOverlayView(context: Context, attrs: AttributeSet?) : View(context, attrs) {

    private val paint = Paint().apply {
        color = Color.BLACK
        alpha = 180
    }

    private val clearPaint = Paint().apply {
        xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
    }

    private val linePaint = Paint().apply {
        color = Color.GREEN
        strokeWidth = 6f
    }

    private val boxPaintMfg = Paint().apply {
        color = Color.GREEN
        style = Paint.Style.STROKE
        strokeWidth = 5f
        alpha = 200
    }

    private val boxPaintExp = Paint().apply {
        color = Color.RED
        style = Paint.Style.STROKE
        strokeWidth = 5f
        alpha = 200
    }

    private val textPaint = Paint().apply {
        color = Color.WHITE
        textSize = 40f
        typeface = Typeface.DEFAULT_BOLD
    }

    private val highlightPaint = Paint().apply {
        color = Color.YELLOW
        style = Paint.Style.FILL
        alpha = 80
    }

    private val highlightBorderPaint = Paint().apply {
        color = Color.YELLOW
        style = Paint.Style.STROKE
        strokeWidth = 3f
        alpha = 180
    }

    private var lineY = -1f
    private var direction = 1
    private var mfgRect: Rect? = null
    private var expRect: Rect? = null
    private var isStaticImageMode = false
    private var detectedTextBlocks: List<Rect> = emptyList()
    private var imgWidth = 0
    private var imgHeight = 0

    fun setImageSize(w: Int, h: Int) {
        imgWidth = w
        imgHeight = h
    }

    fun setStaticImageMode(enabled: Boolean, blocks: List<Rect> = emptyList()) {
        isStaticImageMode = enabled
        detectedTextBlocks = blocks
        invalidate()
    }

    fun updateBoxes(mfg: Rect?, exp: Rect?) {
        mfgRect = mfg
        expRect = exp
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (isStaticImageMode) {
            drawStaticProcessing(canvas)
            return
        }

        val margin = width * 0.1f
        val left = margin
        val top = height * 0.2f
        val right = width - margin
        val bottom = height * 0.8f

        if (lineY == -1f) lineY = top

        // Dark background
        val layerId = canvas.saveLayer(0f, 0f, width.toFloat(), height.toFloat(), null)
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)

        // Clear center (rectangle instead of square)
        canvas.drawRect(left, top, right, bottom, clearPaint)
        canvas.restoreToCount(layerId)

        // Draw live boxes
        mfgRect?.let {
            canvas.drawRect(it, boxPaintMfg)
            canvas.drawText("MFG", it.left.toFloat(), it.top.toFloat() - 10f, textPaint)
        }
        expRect?.let {
            canvas.drawRect(it, boxPaintExp)
            canvas.drawText("EXP", it.left.toFloat(), it.top.toFloat() - 10f, textPaint)
        }

        // Animate scan line
        lineY += 10 * direction
        if (lineY > (height * 0.8f)) {
            lineY = height * 0.8f
            direction = -1
        } else if (lineY < (height * 0.2f)) {
            lineY = height * 0.2f
            direction = 1
        }

        canvas.drawLine(left, lineY, right, lineY, linePaint)

        postInvalidateOnAnimation()
    }

    private fun drawStaticProcessing(canvas: Canvas) {
        if (imgWidth <= 0 || imgHeight <= 0) return

        val viewWidth = width.toFloat()
        val viewHeight = height.toFloat()
        
        // Calculate fitCenter scaling and offsets
        val scale = Math.min(viewWidth / imgWidth, viewHeight / imgHeight)
        val dx = (viewWidth - imgWidth * scale) / 2
        val dy = (viewHeight - imgHeight * scale) / 2

        val imgTop = dy
        val imgBottom = dy + imgHeight * scale
        val imgLeft = dx
        val imgRight = dx + imgWidth * scale

        if (lineY == -1f || lineY < imgTop || lineY > imgBottom) lineY = imgTop

        // Dim background outside the image area (if any) and slightly over the image
        canvas.drawColor(Color.argb(100, 0, 0, 0))
        
        // Draw highlights for text blocks that the scan line is currently over
        for (rect in detectedTextBlocks) {
            val scaledRect = RectF(
                rect.left * scale + dx,
                rect.top * scale + dy,
                rect.right * scale + dx,
                rect.bottom * scale + dy
            )
            
            // Only highlight if the scan line is touching the rect 
            // AND the block has a reasonable size (filter noise)
            if (lineY >= scaledRect.top && lineY <= scaledRect.bottom) {
                if (rect.width() > 10 && rect.height() > 5) {
                    canvas.drawRect(scaledRect, highlightPaint)
                    canvas.drawRect(scaledRect, highlightBorderPaint)
                }
            }
        }

        // Animate scan line within the image boundaries
        lineY += 25 * direction
        if (lineY > imgBottom) {
            lineY = imgBottom
            direction = -1
        } else if (lineY < imgTop) {
            lineY = imgTop
            direction = 1
        }

        // Professional white scan line with a glow, confined to the image width
        canvas.drawLine(imgLeft, lineY, imgRight, lineY, linePaint.apply { 
            color = Color.WHITE
            strokeWidth = 10f
            alpha = 255 
        })

        postInvalidateOnAnimation()
    }
}
