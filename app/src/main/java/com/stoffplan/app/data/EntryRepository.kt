package com.stoffplan.app.data

import kotlinx.coroutines.flow.Flow

class EntryRepository(private val dao: EntryDao) {
    fun observeAll(): Flow<List<Entry>> = dao.observeAll()
    suspend fun getById(id: Long): Entry? = dao.getById(id)
    suspend fun getAllOnce(): List<Entry> = dao.getAllOnce()
    suspend fun upsert(entry: Entry): Long =
        if (entry.id == 0L) dao.insert(entry) else { dao.update(entry); entry.id }
    suspend fun delete(entry: Entry) = dao.delete(entry)
    suspend fun deleteAll() = dao.deleteAll()
}
