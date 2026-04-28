package com.aurex.scanner

import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.animation.AnimationUtils
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.aurex.scanner.data.Product
import com.aurex.scanner.scanner.TextParser
import com.bumptech.glide.Glide
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

class ProductAdapter(
    private val list: List<Product>,
    private val onClick: (Product) -> Unit,
    private val onEdit: (Product) -> Unit,
    private val onDelete: (Product) -> Unit,
    private val onViewImage: (Product) -> Unit
) : RecyclerView.Adapter<ProductAdapter.ViewHolder>() {

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val name: TextView = view.findViewById(R.id.name)
        val expiry: TextView = view.findViewById(R.id.expiry)
        val remainingDays: TextView = view.findViewById(R.id.remaining_days)
        val quantity: TextView = view.findViewById(R.id.quantity)
        val image: ImageView = view.findViewById(R.id.imgProduct)
        val imgSynced: ImageView = view.findViewById(R.id.imgSynced)
        val btnEdit: ImageButton = view.findViewById(R.id.btnEditProduct)
        val card: com.google.android.material.card.MaterialCardView = view.findViewById(R.id.cardProduct)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_product, parent, false)
        return ViewHolder(view)
    }

    override fun getItemCount() = list.size

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = list[position]
        val context = holder.itemView.context
        
        holder.name.text = item.name
        holder.expiry.text = "EXP: ${item.expDate ?: context.getString(R.string.na)}"
        
        val sizeText = item.size?.let { " | $it" } ?: ""
        val warehouseText = item.warehouseName?.let { " | ${context.getString(R.string.wh)} $it" } ?: ""
        holder.quantity.text = "${context.getString(R.string.qty)} ${item.quantity}$sizeText$warehouseText"

        // Calculate Remaining Days
        val daysLeft = calculateDaysLeft(item.expDate)
        
        if (daysLeft == null) {
            holder.remainingDays.visibility = View.GONE
            holder.card.strokeColor = Color.parseColor("#E0E0E0")
        } else {
            holder.remainingDays.visibility = View.VISIBLE
            when {
                daysLeft < 0 -> {
                    holder.remainingDays.text = context.getString(R.string.expired_by, Math.abs(daysLeft))
                    holder.remainingDays.setTextColor(Color.RED)
                    holder.card.strokeColor = Color.RED
                    holder.card.strokeWidth = 3
                    startBlink(holder.remainingDays)
                }
                daysLeft == 0L -> {
                    holder.remainingDays.text = context.getString(R.string.expires_today)
                    holder.remainingDays.setTextColor(Color.RED)
                    holder.card.strokeColor = Color.RED
                    holder.card.strokeWidth = 3
                    startBlink(holder.remainingDays)
                }
                daysLeft <= 30 -> {
                    holder.remainingDays.text = context.getString(R.string.remaining_days, daysLeft)
                    holder.remainingDays.setTextColor(Color.parseColor("#E53935")) // Reddish
                    holder.card.strokeColor = Color.parseColor("#FFD700") // Gold for warning
                    holder.card.strokeWidth = 2
                    startBlink(holder.remainingDays)
                }
                else -> {
                    holder.remainingDays.text = context.getString(R.string.remaining_days, daysLeft)
                    holder.remainingDays.setTextColor(Color.parseColor("#2E7D32")) // Green
                    holder.card.strokeColor = Color.parseColor("#E0E0E0")
                    holder.card.strokeWidth = 1
                    holder.remainingDays.clearAnimation()
                }
            }
        }

        Glide.with(holder.image.context)
            .load(item.imagePath)
            .placeholder(android.R.drawable.ic_menu_report_image)
            .error(android.R.drawable.ic_menu_report_image)
            .centerCrop()
            .into(holder.image)

        holder.image.setOnClickListener { onViewImage(item) }
        holder.btnEdit.setOnClickListener { onEdit(item) }
        holder.itemView.setOnClickListener { onClick(item) }
        
        holder.imgSynced.visibility = if (item.isSynced) View.VISIBLE else View.GONE
        
        holder.itemView.setOnLongClickListener {
            onDelete(item)
            true
        }
    }

    private fun calculateDaysLeft(expDate: String?): Long? {
        if (expDate == null) return null
        return try {
            val sortableDate = TextParser.convertToSortable(expDate)
            val sdf = SimpleDateFormat("yyyyMMdd", Locale.US)
            val expiry = sdf.parse(sortableDate) ?: return null
            
            val today = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.time
            
            val diff = expiry.time - today.time
            TimeUnit.DAYS.convert(diff, TimeUnit.MILLISECONDS)
        } catch (e: Exception) {
            null
        }
    }

    private fun startBlink(view: View) {
        val anim = AnimationUtils.loadAnimation(view.context, R.anim.blink)
        view.startAnimation(anim)
    }
}
