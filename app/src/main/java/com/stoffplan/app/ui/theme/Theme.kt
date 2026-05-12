package com.stoffplan.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkScheme = darkColorScheme(
    primary = Color(0xFFB39DDB),
    secondary = Color(0xFF80CBC4),
    tertiary = Color(0xFFFFAB91),
    background = Color(0xFF120F1C),
    surface = Color(0xFF1F1B2E),
    onPrimary = Color.Black,
    onBackground = Color(0xFFE8E5F1),
    onSurface = Color(0xFFE8E5F1)
)

private val LightScheme = lightColorScheme(
    primary = Color(0xFF5E35B1),
    secondary = Color(0xFF00897B),
    tertiary = Color(0xFFD84315)
)

@Composable
fun StoffPlanTheme(
    useDark: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (useDark) DarkScheme else LightScheme,
        content = content
    )
}
