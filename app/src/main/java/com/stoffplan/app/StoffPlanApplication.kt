package com.stoffplan.app

import android.app.Application
import com.stoffplan.app.data.AppDatabase
import com.stoffplan.app.data.EntryRepository

class StoffPlanApplication : Application() {
    val database by lazy { AppDatabase.get(this) }
    val repository by lazy { EntryRepository(database.entryDao()) }
}
