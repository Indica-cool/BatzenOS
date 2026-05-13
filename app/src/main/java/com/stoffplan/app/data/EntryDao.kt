package com.stoffplan.app.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface EntryDao {
    @Query("SELECT * FROM entries ORDER BY timestamp DESC")
    fun observeAll(): Flow<List<Entry>>

    @Query("SELECT * FROM entries WHERE id = :id")
    suspend fun getById(id: Long): Entry?

    @Query("SELECT * FROM entries ORDER BY timestamp DESC")
    suspend fun getAllOnce(): List<Entry>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entry: Entry): Long

    @Update
    suspend fun update(entry: Entry)

    @Delete
    suspend fun delete(entry: Entry)

    @Query("DELETE FROM entries")
    suspend fun deleteAll()
}
