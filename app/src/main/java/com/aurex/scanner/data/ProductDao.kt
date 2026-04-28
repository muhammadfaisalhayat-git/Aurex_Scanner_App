package com.aurex.scanner.data

import androidx.lifecycle.LiveData
import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update

@Dao
interface ProductDao {

    @Insert(onConflict = androidx.room.OnConflictStrategy.REPLACE)
    suspend fun insert(product: Product)

    @Insert(onConflict = androidx.room.OnConflictStrategy.REPLACE)
    suspend fun insertAll(products: List<Product>)

    @Update
    suspend fun update(product: Product)

    @Update
    suspend fun updateAll(products: List<Product>)

    @Delete
    suspend fun delete(product: Product)

    @Query("DELETE FROM Product")
    suspend fun deleteAll()

    @Query("SELECT * FROM Product ORDER BY id DESC")
    fun getAll(): LiveData<List<Product>>

    @Query("SELECT * FROM Product ORDER BY category ASC, id DESC")
    fun getAllSortedByCategory(): LiveData<List<Product>>

    @Query("SELECT * FROM Product ORDER BY warehouseName ASC, id DESC")
    fun getAllSortedByWarehouse(): LiveData<List<Product>>

    @Query("SELECT * FROM Product ORDER BY expDate ASC")
    fun getAllSortedByExpiry(): LiveData<List<Product>>
    
    // Keeping a non-LiveData version for the Worker if needed, 
    // or we can use getValue() / observe.
    @Query("SELECT * FROM Product ORDER BY id DESC")
    suspend fun getAllList(): List<Product>

    @Query("SELECT * FROM Product WHERE productCode = :code LIMIT 1")
    suspend fun getByProductCode(code: String): Product?

    @Query("SELECT DISTINCT category FROM Product WHERE category IS NOT NULL AND category != '' ORDER BY category ASC")
    suspend fun getAllCategories(): List<String>
}
