package com.stoffplan.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.stoffplan.app.data.Entry
import com.stoffplan.app.data.Route
import com.stoffplan.app.ui.EntryViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditScreen(
    vm: EntryViewModel,
    entryId: Long?,
    onDone: () -> Unit
) {
    var loaded by remember { mutableStateOf(entryId == null) }
    var entry by remember { mutableStateOf(Entry()) }

    LaunchedEffect(entryId) {
        if (entryId != null) {
            vm.load(entryId)?.let { entry = it }
            loaded = true
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (entryId == null) "Neuer Eintrag" else "Eintrag bearbeiten") },
                navigationIcon = {
                    IconButton(onClick = onDone) {
                        Icon(Icons.Default.ArrowBack, "Zurück")
                    }
                },
                actions = {
                    IconButton(onClick = {
                        vm.save(entry) { onDone() }
                    }) { Icon(Icons.Default.Check, "Speichern") }
                }
            )
        }
    ) { padding ->
        if (!loaded) {
            Box(Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            return@Scaffold
        }

        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedTextField(
                value = entry.substance,
                onValueChange = { entry = entry.copy(substance = it) },
                label = { Text("Substanz") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = entry.doseAmount?.toString() ?: "",
                    onValueChange = { entry = entry.copy(doseAmount = it.toDoubleOrNull()) },
                    label = { Text("Dosis") },
                    singleLine = true,
                    keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.weight(1f)
                )
                OutlinedTextField(
                    value = entry.doseUnit,
                    onValueChange = { entry = entry.copy(doseUnit = it) },
                    label = { Text("Einheit") },
                    singleLine = true,
                    modifier = Modifier.weight(1f)
                )
            }

            RouteDropdown(entry.route) { entry = entry.copy(route = it) }

            SectionTitle("Wirkung & Dauer")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MinuteField("Onset", entry.onsetMinutes) { entry = entry.copy(onsetMinutes = it) }
                MinuteField("Peak", entry.peakMinutes) { entry = entry.copy(peakMinutes = it) }
                MinuteField("Comedown", entry.comedownMinutes) { entry = entry.copy(comedownMinutes = it) }
            }
            OutlinedTextField(
                value = entry.effects,
                onValueChange = { entry = entry.copy(effects = it) },
                label = { Text("Wirkungsbeschreibung") },
                minLines = 2,
                modifier = Modifier.fillMaxWidth()
            )

            SectionTitle("Mood (1–10)")
            MoodSlider("Vorher", entry.moodBefore) { entry = entry.copy(moodBefore = it) }
            MoodSlider("Nachher", entry.moodAfter) { entry = entry.copy(moodAfter = it) }

            SectionTitle("Kontext & Setting")
            OutlinedTextField(
                value = entry.location,
                onValueChange = { entry = entry.copy(location = it) },
                label = { Text("Wo") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = entry.company,
                onValueChange = { entry = entry.copy(company = it) },
                label = { Text("Mit wem") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = entry.notes,
                onValueChange = { entry = entry.copy(notes = it) },
                label = { Text("Notizen") },
                minLines = 3,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleSmall)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RouteDropdown(current: Route, onSelect: (Route) -> Unit) {
    var open by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = open, onExpandedChange = { open = it }) {
        OutlinedTextField(
            value = current.name.lowercase(),
            onValueChange = {},
            readOnly = true,
            label = { Text("Konsumform") },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = open) },
            modifier = Modifier.menuAnchor().fillMaxWidth()
        )
        ExposedDropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            Route.values().forEach { r ->
                DropdownMenuItem(
                    text = { Text(r.name.lowercase()) },
                    onClick = { onSelect(r); open = false }
                )
            }
        }
    }
}

@Composable
private fun RowScope.MinuteField(label: String, value: Int?, onChange: (Int?) -> Unit) {
    OutlinedTextField(
        value = value?.toString() ?: "",
        onValueChange = { onChange(it.toIntOrNull()) },
        label = { Text("$label (min)") },
        singleLine = true,
        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Number),
        modifier = Modifier.weight(1f)
    )
}

@Composable
private fun MoodSlider(label: String, value: Int?, onChange: (Int?) -> Unit) {
    val v = (value ?: 5).toFloat()
    Column {
        Text("$label: ${value ?: "—"}")
        Slider(
            value = v,
            onValueChange = { onChange(it.toInt()) },
            valueRange = 1f..10f,
            steps = 8
        )
    }
}
