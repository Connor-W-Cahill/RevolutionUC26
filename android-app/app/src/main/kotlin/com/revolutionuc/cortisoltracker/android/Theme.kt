package com.revolutionuc.cortisoltracker.android

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val DeepTeal = Color(0xFF1A6B5C)
val SoftTeal = Color(0xFF2D9F8F)
val Mint = Color(0xFFA8E6CF)
val StressLow = Color(0xFFA8E6CF)
val StressModerate = Color(0xFFFFD93D)
val StressHigh = Color(0xFFFF8C42)
val StressVeryHigh = Color(0xFFE85D75)
val Background = Color(0xFFF8F9FA)
val CardBackground = Color(0xFFFFFFFF)
val TextPrimary = Color(0xFF1A1A2E)
val TextSecondary = Color(0xFF6B7280)
val DividerColor = Color(0xFFE5E7EB)
val CalmBlue = Color(0xFF5B9BD5)
val SoftPurple = Color(0xFF8B7EC8)
val WarmCoral = Color(0xFFF0A1A8)

private val LightColors = lightColorScheme(
    primary = DeepTeal,
    secondary = SoftTeal,
    tertiary = SoftPurple,
    background = Background,
    surface = CardBackground,
    onPrimary = Color.White,
    onSecondary = Color.White,
    onBackground = TextPrimary,
    onSurface = TextPrimary
)

private val DarkColors = darkColorScheme(
    primary = Mint,
    secondary = SoftTeal,
    tertiary = SoftPurple
)

@Composable
fun CortisolTrackerTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        content = content
    )
}
