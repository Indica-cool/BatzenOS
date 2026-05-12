package com.stoffplan.app.ui.screens

import android.content.Intent
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.stoffplan.app.ui.EntryViewModel
import com.stoffplan.app.util.Exporter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: EntryViewModel, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var confirmWipe by remember { mutableStateOf(false) }
    var snack by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Einstellungen") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "Zurück") }
                }
            )
        },
        snackbarHost = {
            snack?.let {
                Snackbar(modifier = Modifier.padding(12.dp)) { Text(it) }
            }
        }
    ) { padding ->
        Column(
            Modifier.padding(padding).fillMaxSize().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("Export", style = MaterialTheme.typography.titleMedium)
            Text(
                "Alle Daten bleiben lokal auf dem Gerät. Exporte musst du selbst sichern.",
                style = MaterialTheme.typography.bodySmall
            )

            Button(
                onClick = {
                    scope.launch {
                        val entries = vm.loadAll()
                        val content = Exporter.toJson(entries)
                        shareFile(context, content, "stoffplan-${stamp()}.json", "application/json")
                    }
                },
                modifier = Modifier.fillMaxWidth()
            ) { Text("Als JSON exportieren") }

            OutlinedButton(
                onClick = {
                    scope.launch {
                        val entries = vm.loadAll()
                        val content = Exporter.toCsv(entries)
                        shareFile(context, content, "stoffplan-${stamp()}.csv", "text/csv")
                    }
                },
                modifier = Modifier.fillMaxWidth()
            ) { Text("Als CSV exportieren") }

            Spacer(Modifier.height(12.dp))
            Divider()
            Spacer(Modifier.height(4.dp))

            Text("Gefahrenzone", style = MaterialTheme.typography.titleMedium)
            OutlinedButton(
                onClick = { confirmWipe = true },
                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                modifier = Modifier.fillMaxWidth()
            ) { Text("Alle Einträge löschen") }

            Spacer(Modifier.weight(1f))
            Text(
                "Stoff Plan · Privates lokales Tagebuch. Keine Cloud, keine Analytics.",
                style = MaterialTheme.typography.bodySmall
            )
        }
    }

    if (confirmWipe) {
        AlertDialog(
            onDismissRequest = { confirmWipe = false },
            title = { Text("Wirklich alles löschen?") },
            text = { Text("Alle Tagebuch-Einträge werden unwiderruflich entfernt.") },
            confirmButton = {
                TextButton(onClick = {
                    vm.deleteAll()
                    confirmWipe = false
                    snack = "Alle Einträge gelöscht"
                }) { Text("Löschen") }
            },
            dismissButton = {
                TextButton(onClick = { confirmWipe = false }) { Text("Abbrechen") }
            }
        )
    }
}

private suspend fun shareFile(
    context: android.content.Context,
    content: String,
    filename: String,
    mime: String
) {
    val file = withContext(Dispatchers.IO) {
        val dir = File(context.cacheDir, "exports").apply { mkdirs() }
        File(dir, filename).apply { writeText(content) }
    }
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = mime
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(intent, "Export teilen").apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    })
}

private fun stamp(): String =
    SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
