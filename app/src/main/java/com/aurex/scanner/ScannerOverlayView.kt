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

    private var lineY = -1f
    private var direction = 1

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val rectSize = width * 0.7f
        val left = (width - rectSize) / 2
        val top = (height - rectSize) / 2
        val right = left + rectSize
        val bottom = top + rectSize

        if (lineY == -1f) lineY = top

        // Dark background
        val layerId = canvas.saveLayer(0f, 0f, width.toFloat(), height.toFloat(), null)
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)

        // Clear center
        canvas.drawRect(left, top, right, bottom, clearPaint)
        canvas.restoreToCount(layerId)

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
