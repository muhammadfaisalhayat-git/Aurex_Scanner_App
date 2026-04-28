package com.aurex.scanner

import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.api.client.http.FileContent
import com.google.api.services.drive.Drive
import com.google.api.services.drive.model.File
import java.io.IOException
import java.util.concurrent.Executor
import java.util.concurrent.Executors

class DriveServiceHelper(private val mDriveService: Drive) {
    private val mExecutor: Executor = Executors.newSingleThreadExecutor()

    fun uploadFile(filePath: String, fileName: String): Task<String> {
        return Tasks.call(mExecutor) {
            val metadata = File()
                .setName(fileName)
                .setMimeType("application/x-sqlite3")

            val targetFile = java.io.File(filePath)
            if (!targetFile.exists()) {
                throw IOException("File does not exist: $filePath")
            }

            val mediaContent = FileContent("application/x-sqlite3", targetFile)

            try {
                val googleFile = mDriveService.files().create(metadata, mediaContent).execute()
                    ?: throw IOException("Null result when requesting file creation.")
                googleFile.id
            } catch (e: Exception) {
                // Re-throw to be caught by the task's failure listener
                throw IOException("Drive upload failed: ${e.message}", e)
            }
        }
    }
}
