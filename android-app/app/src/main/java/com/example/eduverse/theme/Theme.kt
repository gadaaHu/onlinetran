package com.example.eduverse.theme

import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.Color

object ThemeState {
    var isDark by mutableStateOf(true)

    fun toggle() {
        isDark = !isDark
    }
}

val DarkAppColors = darkColorScheme(
    primary = Color(0xFF8B5CF6),
    onPrimary = Color.White,
    secondary = Color(0xFF10B981),
    background = Color(0xFF0A0A14),
    surface = Color(0xFF131326),
    onBackground = Color(0xFFF8FAFC),
    onSurface = Color(0xFFF8FAFC),
    surfaceVariant = Color(0xFF1E1E35),
    outline = Color(0xFF2E2E48)
)

val LightAppColors = lightColorScheme(
    primary = Color(0xFF6366F1),
    onPrimary = Color.White,
    secondary = Color(0xFF059669),
    background = Color(0xFFF4F6F9),
    surface = Color(0xFFFFFFFF),
    onBackground = Color(0xFF0F172A),
    onSurface = Color(0xFF1E293B),
    surfaceVariant = Color(0xFFE2E8F0),
    outline = Color(0xFFCBD5E1)
)

@Composable
fun EduVerseTheme(
    darkTheme: Boolean = ThemeState.isDark,
    content: @Composable () -> Unit,
) {
    val colorScheme = if (darkTheme) DarkAppColors else LightAppColors
    MaterialTheme(colorScheme = colorScheme, typography = Typography, content = content)
}
