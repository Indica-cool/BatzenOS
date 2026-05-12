package com.stoffplan.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.stoffplan.app.data.Entry
import com.stoffplan.app.ui.EntryViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailScreen(
    vm: EntryViewModel,
    id: Long,
    onEdit: () -> Unit,
    onBack: () -> Unit
) {
    var entry by remember { mutableStateOf<Entry?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }

    LaunchedEffect(id) { entry = vm.load(id) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(entry?.substance?.takeIf { it.isNotBlank() } ?: "Eintrag") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "Zurück") }
                },
                actions = {
                    IconButton(onClick = onEdit) { Icon(Icons.Default.Edit, "Bearbeiten") }
                    IconButton(onClick = { confirmDelete = true }) {
                        Icon(Icons.Default.Delete, "Löschen")
                    }
                }
            )
        }
    ) { padding ->
        val e = entry
        if (e == null) {
            Box(Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            return@Scaffold
        }

        Column(
            Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(format(e.timestamp), style = MaterialTheme.typography.bodyMedium)

            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    e.doseAmount?.let { "${if (it % 1.0 == 0.0) it.toLong() else it} ${e.doseUnit}" } ?: "Dosis: —",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.width(12.dp))
                AssistChip(onClick = {}, label = { Text(e.route.name.lowercase()) })
            }

            Divider()
            Field("Onset", e.onsetMinutes?.let { "$it min" })
            Field("Peak", e.peakMinutes?.let { "$it min" })
            Field("Comedown", e.comedownMinutes?.let { "$it min" })
            Field("Wirkung", e.effects.ifBlank { null })

            Divider()
            Field("Mood vorher", e.moodBefore?.toString())
            Field("Mood nachher", e.moodAfter?.toString())

            Divider()
            Field("Ort", e.location.ifBlank { null })
            Field("Begleitung", e.company.ifBlank { null })
            Field("Notizen", e.notes.ifBlank { null })
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Eintrag löschen?") },
            text = { Text("Dieser Eintrag wird unwiderruflich gelöscht.") },
            confirmButton = {
                TextButton(onClick = {
                    entry?.let { vm.delete(it) }
                    confirmDelete = false
                    onBack()
                }) { Text("Löschen") }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("Abbrechen") }
            }
        )
    }
}

@Composable
private fun Field(label: String, value: String?) {
    if (value == null) return
    Column {
        Text(label, style = MaterialTheme.typography.labelSmall)
        Text(value, style = MaterialTheme.typography.bodyLarge)
    }
}

private fun format(ts: Long): String =
    SimpleDateFormat("EEEE, dd. MMMM yyyy · HH:mm", Locale.GERMANY).format(Date(ts))
