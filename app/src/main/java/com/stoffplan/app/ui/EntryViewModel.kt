package com.stoffplan.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.stoffplan.app.StoffPlanApplication
import com.stoffplan.app.data.Entry
import com.stoffplan.app.data.EntryRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class EntryViewModel(private val repo: EntryRepository) : ViewModel() {

    val entries: StateFlow<List<Entry>> = repo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    suspend fun load(id: Long): Entry? = repo.getById(id)
    suspend fun loadAll(): List<Entry> = repo.getAllOnce()

    fun save(entry: Entry, onDone: (Long) -> Unit = {}) {
        viewModelScope.launch { onDone(repo.upsert(entry)) }
    }

    fun delete(entry: Entry) { viewModelScope.launch { repo.delete(entry) } }
    fun deleteAll() { viewModelScope.launch { repo.deleteAll() } }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as StoffPlanApplication
                EntryViewModel(app.repository)
            }
        }
    }
}
