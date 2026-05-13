package com.stoffplan.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
fun HomeScreen(
    vm: EntryViewModel,
    onAdd: () -> Unit,
    onOpen: (Long) -> Unit,
    onSettings: () -> Unit
) {
    val entries by vm.entries.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Stoff Plan") },
                actions = {
                    IconButton(onClick = onSettings) {
                        Icon(Icons.Default.Settings, contentDescription = "Einstellungen")
                    }
                }
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onAdd,
                icon = { Icon(Icons.Default.Add, null) },
                text = { Text("Neuer Eintrag") }
            )
        }
    ) { padding ->
        if (entries.isEmpty()) {
            Box(
                modifier = Modifier.padding(padding).fillMaxSize().padding(24.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Noch keine Einträge", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Tippe auf „Neuer Eintrag“ um zu starten.",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.padding(padding).fillMaxSize(),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(entries, key = { it.id }) { e ->
                    EntryRow(entry = e, onClick = { onOpen(e.id) })
                }
            }
        }
    }
}

@Composable
private fun EntryRow(entry: Entry, onClick: () -> Unit) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth().clickable { onClick() }
    ) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = if (entry.substance.isBlank()) "(ohne Name)" else entry.substance,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f)
                )
                val dose = entry.doseAmount?.let { "${formatNum(it)} ${entry.doseUnit}" } ?: "—"
                AssistChip(onClick = onClick, label = { Text(dose) })
            }
            Spacer(Modifier.height(4.dp))
            Text(
                formatTime(entry.timestamp) + "  ·  " + entry.route.name.lowercase(),
                style = MaterialTheme.typography.bodySmall
            )
            if (entry.effects.isNotBlank()) {
                Spacer(Modifier.height(6.dp))
                Text(entry.effects, maxLines = 2, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

private fun formatTime(ts: Long): String =
    SimpleDateFormat("dd.MM.yyyy HH:mm", Locale.GERMANY).format(Date(ts))

private fun formatNum(d: Double): String =
    if (d % 1.0 == 0.0) d.toLong().toString() else d.toString()
