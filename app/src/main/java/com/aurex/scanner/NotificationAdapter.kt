package com.aurex.scanner

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.aurex.scanner.data.Notification
import java.text.SimpleDateFormat
import java.util.*

class NotificationAdapter(
    private val notifications: List<Notification>,
    private val onItemClick: (Notification) -> Unit
) : RecyclerView.Adapter<NotificationAdapter.ViewHolder>() {

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val title: TextView = view.findViewById(R.id.txtNotifTitle)
        val message: TextView = view.findViewById(R.id.txtNotifMessage)
        val time: TextView = view.findViewById(R.id.txtNotifTime)
        val unreadDot: View = view.findViewById(R.id.viewUnreadDot)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_notification, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val notif = notifications[position]
        holder.title.text = notif.title
        holder.message.text = notif.message
        
        val sdf = SimpleDateFormat("MMM dd, HH:mm", Locale.getDefault())
        holder.time.text = sdf.format(Date(notif.timestamp))
        
        holder.itemView.setOnClickListener { onItemClick(notif) }
        
        // Premium styling for unread/read states
        if (!notif.read) {
            holder.unreadDot.visibility = View.VISIBLE
            holder.title.setTypeface(null, android.graphics.Typeface.BOLD)
            holder.itemView.alpha = 1.0f
        } else {
            holder.unreadDot.visibility = View.GONE
            holder.title.setTypeface(null, android.graphics.Typeface.NORMAL)
            holder.itemView.alpha = 0.7f
        }
    }

    override fun getItemCount() = notifications.size
}
