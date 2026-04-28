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

    private var lineY = -1f
    private var direction = 1
    private var mfgRect: Rect? = null
    private var expRect: Rect? = null

    fun updateBoxes(mfg: Rect?, exp: Rect?) {
        mfgRect = mfg
        expRect = exp
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

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
        if (lineY > bottom) {
            lineY = bottom
            direction = -1
        } else if (lineY < top) {
            lineY = top
            direction = 1
        }

        canvas.drawLine(left, lineY, right, lineY, linePaint)

        postInvalidateOnAnimation()
    }
}
