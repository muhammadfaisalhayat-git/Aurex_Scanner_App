package com.aurex.scanner

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.aurex.scanner.data.User

class UserAdapter(
    private val users: List<User>,
    private val onEdit: (User) -> Unit,
    private val onDelete: (User) -> Unit,
    private val onApprove: (User) -> Unit
) : RecyclerView.Adapter<UserAdapter.UserViewHolder>() {

    class UserViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val name: TextView = view.findViewById(R.id.txtUserName)
        val email: TextView = view.findViewById(R.id.txtUserEmail)
        val position: TextView = view.findViewById(R.id.txtUserPosition)
        val status: TextView = view.findViewById(R.id.txtUserStatus)
        val dailyScans: TextView = view.findViewById(R.id.txtDailyScans)
        val btnApprove: ImageButton = view.findViewById(R.id.btnApproveUser)
        val btnEdit: ImageButton = view.findViewById(R.id.btnEditUser)
        val btnDelete: ImageButton = view.findViewById(R.id.btnDeleteUser)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): UserViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_user, parent, false)
        return UserViewHolder(view)
    }

    override fun onBindViewHolder(holder: UserViewHolder, position: Int) {
        val user = users[position]
        holder.name.text = user.name
        holder.email.text = user.email
        holder.position.text = user.position
        
        if (user.isAdmin) {
            holder.status.visibility = View.VISIBLE
            holder.status.setText(R.string.status_admin)
            holder.status.setBackgroundResource(android.R.color.holo_red_dark)
            holder.btnApprove.visibility = View.GONE
        } else if (!user.isApproved) {
            holder.status.visibility = View.VISIBLE
            holder.status.setText(R.string.status_pending)
            holder.status.setBackgroundResource(android.R.color.holo_orange_dark)
            holder.btnApprove.visibility = View.VISIBLE
        } else {
            holder.status.visibility = View.GONE
            holder.btnApprove.visibility = View.GONE
        }

        if (user.dailyScans > 0) {
            holder.dailyScans.visibility = View.VISIBLE
            holder.dailyScans.text = "Today's Scans: ${user.dailyScans}"
        } else {
            holder.dailyScans.visibility = View.GONE
        }

        holder.btnApprove.setOnClickListener { onApprove(user) }
        holder.btnEdit.setOnClickListener { onEdit(user) }
        holder.btnDelete.setOnClickListener { onDelete(user) }
    }

    override fun getItemCount() = users.size
}
