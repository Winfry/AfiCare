import 'package:flutter/material.dart';

/// Canonical brand palette for AfiCare MediLink — single source of truth
/// for every surface, text, border and icon-tint the app uses.
///
/// Values are taken directly from the brand spec. Don't add new colors
/// here casually — if a screen needs a new tint, derive it from one of
/// these (e.g. `.withOpacity()` or a `Color.lerp` toward white) rather
/// than introducing an unrelated hue.
class AppColors {
  AppColors._();

  // ── Core brand ──────────────────────────────────────────────────────
  static const Color primaryNavy    = Color(0xFF1D3557);
  static const Color deepNavy       = Color(0xFF152A45);
  static const Color steelBlue      = Color(0xFF457B9D);
  static const Color lightBlue      = Color(0xFF64B5F6);

  /// Middle stop for navy gradients (hero cards, brand panels) — sits
  /// between [primaryNavy] and [deepNavy].
  static const Color navyGradientMid = Color(0xFF24456B);

  // ── Role colors ─────────────────────────────────────────────────────
  static const Color patientColor = primaryNavy;
  static const Color doctorColor  = primaryNavy;
  static const Color nurseColor   = steelBlue;
  static const Color adminColor   = Color(0xFF6D597A);

  // ── Triage / status ─────────────────────────────────────────────────
  static const Color emergency  = Color(0xFFB71C1C);
  static const Color urgent     = Color(0xFFE65100);
  static const Color lessUrgent = Color(0xFFFFA000);
  static const Color nonUrgent  = Color(0xFF2E7D32);

  // ── Canopy (primary teal — used by login, theme buttons/inputs) ─────
  static const Color canopyDark  = Color(0xFF194D43);
  static const Color canopy      = Color(0xFF206B5D);
  static const Color canopyLight = Color(0xFF2E8C7A);
  static const Color canopyPale  = Color(0xFFC7EDE4);

  // ── Marigold (accent — used by login, theme) ────────────────────────
  static const Color marigold     = Color(0xFFF3A83C);
  static const Color marigoldDark = Color(0xFFD98E1E);
  static const Color marigoldSoft = Color(0xFFFFE8C4);

  // ── Clay (error / urgent — used by theme) ───────────────────────────
  static const Color clay      = Color(0xFFC7553B);
  static const Color clayLight = Color(0xFFE8957F);
  static const Color clayBg    = Color(0xFFFDECE8);

  // ── Sage (success / healthy — used by theme) ────────────────────────
  static const Color sage      = Color(0xFF5D9973);
  static const Color sageLight = Color(0xFF8BBD9F);
  static const Color sageBg    = Color(0xFFE4F3EA);

  // ── Steel (info — used by theme) ────────────────────────────────────
  static const Color steel      = Color(0xFF55708A);
  static const Color steelLight = Color(0xFF8BA2BA);
  static const Color steelBg    = Color(0xFFE6EDF4);

  // ── Text hierarchy ──────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF152A45);
  static const Color textSecondary = Color(0xFF445566);
  static const Color textMuted     = Color(0xFF55708A);
  static const Color textInverse   = Color(0xFFFFFFFF);
  static const Color textOnCanopy  = Color(0xFFFFFFFF);

  // ── Surfaces (light theme) ──────────────────────────────────────────
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color mistBackground = Color(0xFFEEF2F7);
  static const Color overlay        = Color(0xCC000000);
  static const Color shadow         = Color(0x1A152A45);

  // ── Input / form ────────────────────────────────────────────────────
  static const Color inputFill     = Color(0xFFF5F5F5);
  static const Color inputFillDark = Color(0xFF1E2D42);
  static const Color borderSubtle  = Color(0xFFDCE3EA);

  // ── Dark theme surfaces ─────────────────────────────────────────────
  static const Color darkAppBar    = Color(0xFF212121);
  static const Color darkScaffold  = Color(0xFF121212);
  static const Color darkSurface   = Color(0xFF262626);
  static const Color darkBackground= Color(0xFF0E1826);
  static const Color darkCard      = Color(0xFF162032);
  static const Color darkBorder    = Color(0xFF263348);

  // ── Icon tint pairs (background + foreground) ────────────────────────
  // Kept as a tight set of tonal pairs within the brand's blue family,
  // plus green for money/success. Reused across dashboards so icon
  // coloring never turns into a rainbow of one-offs.
  static const Color tintNavyBg      = Color(0xFFE8EDF3);
  static const Color tintNavyFg      = deepNavy;

  static const Color tintSteelBg     = Color(0xFFE9F1F5);
  static const Color tintSteelFg     = steel;

  static const Color tintLightBlueBg = Color(0xFFE5F2FD);
  static const Color tintLightBlueFg = Color(0xFF1565C0);

  static const Color tintSuccessBg   = Color(0xFFEAF6EE);
  static const Color tintSuccessFg   = sage;

  static const Color tintUrgentBg    = Color(0xFFFDEEE3);
  static const Color tintUrgentFg    = clay;

  static const Color tintAdminBg     = Color(0xFFEFEAF2);
  static const Color tintAdminFg     = Color(0xFF6A3DB5);
}
