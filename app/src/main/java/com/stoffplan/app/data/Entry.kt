package com.stoffplan.app.data

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class Route { ORAL, NASAL, SMOKED, VAPED, INJECTED, RECTAL, SUBLINGUAL, OTHER }

@Entity(tableName = "entries")
data class Entry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val timestamp: Long = System.currentTimeMillis(),
    val substance: String = "",
    val doseAmount: Double? = null,
    val doseUnit: String = "mg",
    val route: Route = Route.ORAL,
    val onsetMinutes: Int? = null,
    val peakMinutes: Int? = null,
    val comedownMinutes: Int? = null,
    val effects: String = "",
    val moodBefore: Int? = null,
    val moodAfter: Int? = null,
    val location: String = "",
    val company: String = "",
    val notes: String = ""
)
