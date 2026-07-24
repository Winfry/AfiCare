import 'package:flutter/material.dart';

/// Canonical brand palette – single source of truth for every surface,
/// text, border and icon-tint the app uses.
class AppColors {
  AppColors._();

  // ── Deep navy (primary dark) ────────────────────────────────────────
  static const deepNavy   = Color(0xFF15243D);
  static const primaryNavy= Color(0xFF1A3355);
  static const navyMid    = Color(0xFF1D3355);
  static const navyLight  = Color(0xFF2B4468);
  static const lightBlue  = Color(0xFF8CB4D5);

  // ── Canopy (primary teal) ───────────────────────────────────────────
  static const canopyDark = Color(0xFF194D43);
  static const canopy     = Color(0xFF206B5D);
  static const canopyLight= Color(0xFF2E8C7A);
  static const canopyPale = Color(0xFFC7EDE4);

  // ── Marigold (accent) ───────────────────────────────────────────────
  static const marigold       = Color(0xFFF3A83C);
  static const marigoldDark   = Color(0xFFD98E1E);
  static const marigoldSoft   = Color(0xFFFFE8C4);

  // ── Clay (error / urgent) ───────────────────────────────────────────
  static const clay       = Color(0xFFC7553B);
  static const clayLight  = Color(0xFFE8957F);
  static const clayBg     = Color(0xFFFDECE8);

  // ── Sage (success / healthy) ────────────────────────────────────────
  static const sage       = Color(0xFF5D9973);
  static const sageLight  = Color(0xFF8BBD9F);
  static const sageBg     = Color(0xFFE4F3EA);

  // ── Steel (info) ────────────────────────────────────────────────────
  static const steel      = Color(0xFF55708A);
  static const steelLight = Color(0xFF8BA2BA);
  static const steelBg    = Color(0xFFE6EDF4);

  // ── Text hierarchy ──────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF15243D);
  static const textSecondary = Color(0xFF445566);
  static const textMuted     = Color(0xFF6E7F90);
  static const textInverse   = Color(0xFFFFFFFF);
  static const textOnCanopy  = Color(0xFFFFFFFF);

  // ── Surfaces ────────────────────────────────────────────────────────
  static const pageBackground = Color(0xFFF8FAFC);
  static const cardBackground = Color(0xFFFFFFFF);
  static const mistBackground = Color(0xFFEEF2F7);
  static const overlay        = Color(0xCC000000);
  static const shadow         = Color(0x1A15243D);

  // ── Input / form ────────────────────────────────────────────────────
  static const inputFill     = Color(0xFFF5F5F5);
  static const inputFillDark = Color(0xFF1E2D42);
  static const borderSubtle  = Color(0xFFDCE3EA);

  // ── Dark-theme surfaces ─────────────────────────────────────────────
  static const darkBackground = Color(0xFF0E1826);
  static const darkCard       = Color(0xFF162032);
  static const darkBorder     = Color(0xFF263348);

  // ── Icon tint pairs (background tint + foreground) ───────────────────
  static const tintNavyBg      = Color(0xFFDDE5F0);
  static const tintNavyFg      = deepNavy;

  static const tintSteelBg     = Color(0xFFE1EBF3);
  static const tintSteelFg     = steel;

  static const tintLightBlueBg = Color(0xFFDFF0FC);
  static const tintLightBlueFg = Color(0xFF1A6FAF);

  static const tintSuccessBg   = sageBg;
  static const tintSuccessFg   = sage;

  static const tintUrgentBg    = clayBg;
  static const tintUrgentFg    = clay;

  static const tintAdminBg     = Color(0xFFF1E8FD);
  static const tintAdminFg     = Color(0xFF6A3DB5);
}
