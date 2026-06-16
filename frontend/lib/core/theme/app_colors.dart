import 'package:flutter/material.dart';

class AppColors {
  // ── Brand Primary ─────────────────────────────────────────
  static const Color primary       = Color(0xFF2563EB); // Blue 600
  static const Color primaryDark   = Color(0xFF1E3A8A); // Blue 900
  static const Color primaryLight  = Color(0xFFEFF6FF); // Blue 50
  static const Color accent        = Color(0xFF06B6D4); // Cyan 500

  // ── Semantic ──────────────────────────────────────────────
  static const Color success       = Color(0xFF16A34A);
  static const Color successLight  = Color(0xFFF0FDF4);
  static const Color warning       = Color(0xFFD97706);
  static const Color warningLight  = Color(0xFFFFFBEB);
  static const Color danger        = Color(0xFFDC2626);
  static const Color dangerLight   = Color(0xFFFEF2F2);
  static const Color info          = Color(0xFF0891B2);
  static const Color infoLight     = Color(0xFFECFEFF);

  // ── Light Neutrals ────────────────────────────────────────
  static const Color background    = Color(0xFFF8FAFC);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceAlt    = Color(0xFFF1F5F9);
  static const Color border        = Color(0xFFE2E8F0);
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textDisabled  = Color(0xFFCBD5E1);

  // ── Dark Neutrals ─────────────────────────────────────────
  static const Color darkBackground    = Color(0xFF0F172A);
  static const Color darkSurface       = Color(0xFF1E293B);
  static const Color darkSurfaceAlt    = Color(0xFF334155);
  static const Color darkBorder        = Color(0xFF475569);
  static const Color darkTextPrimary   = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextDisabled  = Color(0xFF475569);

  // ── Dark Semantic Tints (for icon backgrounds in dark mode) ───────────────
  static const Color darkPrimaryTint   = Color(0xFF1E3A5F); // primary bg in dark
  static const Color darkSuccessTint   = Color(0xFF14532D); // success bg in dark
  static const Color darkWarningTint   = Color(0xFF451A03); // warning bg in dark
  static const Color darkDangerTint    = Color(0xFF450A0A); // danger bg in dark

  // ── Role Badges ───────────────────────────────────────────
  static const Color roleAdmin    = Color(0xFF7C3AED);
  static const Color roleManajer  = Color(0xFF0891B2);
  static const Color roleHrd      = Color(0xFF059669);
  static const Color roleKaryawan = Color(0xFF2563EB);

  // ── Status Colors ─────────────────────────────────────────
  static const Color statusHadir     = Color(0xFF16A34A);
  static const Color statusTerlambat = Color(0xFFD97706);
  static const Color statusIzin      = Color(0xFF0891B2);
  static const Color statusAlpha     = Color(0xFFDC2626);
  static const Color statusPending   = Color(0xFFF59E0B);
  static const Color statusApproved  = Color(0xFF16A34A);
  static const Color statusRejected  = Color(0xFFDC2626);
}
