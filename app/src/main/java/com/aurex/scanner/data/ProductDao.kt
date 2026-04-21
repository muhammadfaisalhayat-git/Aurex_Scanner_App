package com.aurex.scanner.data

import androidx.lifecycle.LiveData
import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao
interface ProductDao {

    @Insert
    suspend fun insert(product: Product)

    @Query("SELECT * FROM Product ORDER BY id DESC")
    fun getAll(): LiveData<List<Product>>
    
    // Keeping a non-LiveData version for the Worker if needed, 
    // or we can use getValue() / observe.
    @Query("SELECT * FROM Product ORDER BY id DESC")
    suspend fun getAllList(): List<Product>
}
