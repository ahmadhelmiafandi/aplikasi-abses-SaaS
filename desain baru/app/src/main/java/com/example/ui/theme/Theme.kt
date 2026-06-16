package com.example.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkColorScheme = darkColorScheme(
    primary = NaturalPrimaryGreenDark,
    onPrimary = Color(0xFF0F3900),
    primaryContainer = Color(0xFF205105),
    onPrimaryContainer = Color(0xFFA8EDA2),
    secondary = NaturalTextSecondaryDark,
    onSecondary = Color(0xFF26341A),
    background = NaturalBgDark,
    onBackground = NaturalTextPrimaryDark,
    surface = NaturalBgDark,
    onSurface = NaturalTextPrimaryDark,
    surfaceVariant = NaturalLightGreenCardDark,
    onSurfaceVariant = Color(0xFFC5C8BA),
    error = NaturalRedDark,
    onError = Color(0xFF690005),
    outline = NaturalBorderDark,
    secondaryContainer = NaturalNeutralContainerDark
)

private val LightColorScheme = lightColorScheme(
    primary = NaturalPrimaryGreenLight,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFB7F397),
    onPrimaryContainer = Color(0xFF042100),
    secondary = NaturalTextSecondaryLight,
    onSecondary = Color.White,
    background = NaturalBgLight,
    onBackground = NaturalTextPrimaryLight,
    surface = NaturalBgLight,
    onSurface = NaturalTextPrimaryLight,
    surfaceVariant = NaturalLightGreenCardLight,
    onSurfaceVariant = NaturalTextPrimaryLight,
    error = NaturalRedLight,
    onError = Color.White,
    outline = NaturalBorderLight,
    secondaryContainer = NaturalNeutralContainerLight
)

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
