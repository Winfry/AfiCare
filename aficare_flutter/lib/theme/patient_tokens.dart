import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the patient app, transcribed from
/// `docs/patient_prototype.html` (the approved visual spec).
///
/// Deliberately separate from [AppColors]: that palette is shared with
/// the provider and facility-admin roles, which are NOT part of this
/// redesign and must keep rendering exactly as they do today.
class PT {
  PT._();

  // ── Palette (prototype :root) ───────────────────────────────────────
  static const Color navy   = Color(0xFF07324A); // --n
  static const Color teal   = Color(0xFF2F9F91); // --t  primary accent
  static const Color green  = Color(0xFF3FA46D); // --g
  static const Color page   = Color(0xFFF4F7F6); // --bg
  static const Color ink    = Color(0xFF18313D); // --ink
  static const Color muted  = Color(0xFF70818A); // --m
  static const Color line   = Color(0xFFE4EBED); // --l
  static const Color danger = Color(0xFFD94B55); // --d
  static const Color warn   = Color(0xFFD99531); // --warn
  static const Color white  = Color(0xFFFFFFFF);

  // ── Sidebar rail ────────────────────────────────────────────────────
  static const Color railTop    = Color(0xFF062F46);
  static const Color railBottom = Color(0xFF083C57);
  static const Color railFooter = Color(0xFF083C57);
  static const Color railText   = Color(0xFFDCE9ED);
  static const Color railActive = Color(0x1CFFFFFF);
  static const Color railBorder = Color(0x20FFFFFF);

  static const LinearGradient rail = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [railTop, railBottom],
  );

  // ── Hero + SOS gradients ────────────────────────────────────────────
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A3D58), Color(0xFF2C887F)],
  );

  static const LinearGradient sos = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14394B), Color(0xFF7D3038)],
  );

  // ── Badge tints (bg + fg pairs) ─────────────────────────────────────
  static const Color badgeOkBg    = Color(0xFFEDF7F1);
  static const Color badgeOkFg    = Color(0xFF2D8A5C);
  static const Color badgeWarnBg  = Color(0xFFFFF7E8);
  static const Color badgeWarnFg  = Color(0xFF9A6A16);
  static const Color badgeRedBg   = Color(0xFFFFF0F1);
  static const Color badgeRedFg   = Color(0xFFB43A43);
  static const Color badgeBlueBg  = Color(0xFFEAF4FB);
  static const Color badgeBlueFg  = Color(0xFF2C7299);
  static const Color badgeGrayBg  = Color(0xFFF0F3F4);
  static const Color badgeGrayFg  = Color(0xFF6B7B83);

  // ── Component surfaces ──────────────────────────────────────────────
  static const Color calloutBg       = Color(0xFFEEF8F6);
  static const Color calloutWarnBg   = Color(0xFFFFF7E8);
  static const Color calloutDangerBg = Color(0xFFFFF0F1);
  static const Color viewingBorder   = Color(0xFFF1DDB4);
  static const Color searchFill      = Color(0xFFF4F7F7);
  static const Color tabsTrack       = Color(0xFFEDF2F2);
  static const Color progressTrack   = Color(0xFFE9EFEE);
  static const Color timelineLine    = Color(0xFFDCE7E6);
  static const Color timelineRing    = Color(0xFFDFF4EF);
  static const Color avatarBg        = Color(0xFFDCECE8);
  static const Color avatarDepBg     = Color(0xFFDFF1ED);
  static const Color avatarDepFg     = Color(0xFF1F7A6E);
  static const Color stepNumBg       = Color(0xFFEAF4F2);
  static const Color stepDoneBg      = Color(0xFFF7FBF9);
  static const Color closeBtnBg      = Color(0xFFF0F4F4);
  static const Color toggleOff       = Color(0xFFD5DEE0);

  // ── Radii ───────────────────────────────────────────────────────────
  static const double rCard   = 18;
  static const double rHero   = 22;
  static const double rRow    = 13;
  static const double rButton = 11;
  static const double rPill   = 999;
  static const double rModal  = 20;

  // ── Elevation ───────────────────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A07324A), blurRadius: 30, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> heroShadow = [
    BoxShadow(color: Color(0x1407324A), blurRadius: 35, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> popoverShadow = [
    BoxShadow(color: Color(0x40021823), blurRadius: 50, offset: Offset(0, 18)),
  ];

  // ── Layout ──────────────────────────────────────────────────────────
  static const double maxContentWidth = 1350;
  static const double railWidth = 235;
  static const double railWidthCompact = 205;
  static const double topBarHeight = 68;

  /// Prototype media queries: the rail hides below 700 and narrows
  /// below 900, and grids step down at both points.
  static const double bpMobile = 700;
  static const double bpTablet = 900;

  /// Breakpoints are evaluated against the viewport, not the local
  /// container, because that is what the spec's CSS media queries do --
  /// a container-relative check collapses grids too early inside the
  /// sidebar layout and inside modals.
  static bool isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < bpMobile;
  static bool isTablet(BuildContext c) => MediaQuery.sizeOf(c).width < bpTablet;

  // ── Type scale (Inter, per the approved prototype) ───────────────────
  static TextStyle h1() => GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: ink, height: 1.2);
  static TextStyle h2() => GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: white, height: 1.2);
  static TextStyle h3() => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: ink);

  static TextStyle eyebrow() =>
      GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: teal);

  static TextStyle sub() => GoogleFonts.inter(fontSize: 14, color: muted, height: 1.5);
  static TextStyle body() => GoogleFonts.inter(fontSize: 14, color: ink, height: 1.45);
  static TextStyle rowTitle() => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ink);
  static TextStyle rowSub() => GoogleFonts.inter(fontSize: 12.5, color: muted, height: 1.35);
  static TextStyle label() => GoogleFonts.inter(fontSize: 12, color: muted);
  static TextStyle metric() => GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: ink, height: 1.1);
  static TextStyle score() => GoogleFonts.inter(fontSize: 46, fontWeight: FontWeight.w900, color: teal, height: 1.05);
  static TextStyle badge() => GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800);
  static TextStyle button() => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700);
  static TextStyle navItem() => GoogleFonts.inter(fontSize: 15, color: railText);
  static TextStyle navGroup() =>
      GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1, color: const Color(0x80FFFFFF));
}
