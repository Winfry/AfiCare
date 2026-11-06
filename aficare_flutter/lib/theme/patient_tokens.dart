import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the patient app, transcribed from the approved
/// patient prototype: navy rail, blue accents on a warm paper ground.
///
/// Deliberately separate from [AppColors]: that palette is shared with
/// the provider and facility-admin roles, which are NOT part of this
/// redesign and must keep rendering exactly as they do today.
class PT {
  PT._();

  // ── High contrast ───────────────────────────────────────────────────
  // When the patient turns on High contrast (Accessibility), the colours
  // that carry text, lines and status switch to darker ones: grey text
  // becomes near-black, faint dividers become visible lines. Set by
  // HighContrastScope from her saved preference; never set it elsewhere.
  static bool highContrast = false;
  static Color _pick(Color normal, Color strong) => highContrast ? strong : normal;

  // ── Palette ─────────────────────────────────────────────────────────
  // Values come from the approved patient prototype: navy rail, blue
  // accents, warm paper ground. Field names are deliberately unchanged
  // from the earlier teal set so every screen inherits this without edits.
  // The second colour of each pair is the High contrast one (every text
  // colour on it is at least 7:1 against white, WCAG AAA).
  static Color get navy   => _pick(const Color(0xFF17405B), const Color(0xFF0E2B3E)); // deep blue
  static Color get teal   => _pick(const Color(0xFF2A5F85), const Color(0xFF173F5E)); // primary accent (blue)
  static Color get green  => _pick(const Color(0xFF2D7F62), const Color(0xFF175340));
  static Color get page   => _pick(const Color(0xFFF7F8F5), const Color(0xFFFFFFFF)); // warm paper
  static Color get ink    => _pick(const Color(0xFF20303F), const Color(0xFF0A141D));
  static Color get muted  => _pick(const Color(0xFF717F88), const Color(0xFF2F3B45));
  static Color get line   => _pick(const Color(0xFFE5E8EA), const Color(0xFF6E7B85));
  static Color get danger => _pick(const Color(0xFFBD6256), const Color(0xFF8A2F25)); // coral
  static Color get warn   => _pick(const Color(0xFFB0751D), const Color(0xFF6E450B)); // gold
  static const Color white  = Color(0xFFFFFFFF);
  static const Color gold   = Color(0xFFE5B867); // rail active stripe

  // ── Sidebar rail ────────────────────────────────────────────────────
  static const Color railTop    = Color(0xFF1B3850);
  static const Color railBottom = Color(0xFF152E44);
  static const Color railFooter = Color(0xFF16314A);
  static const Color railText   = Color(0xFFD8E2E8);
  static const Color railActive = Color(0x1FFFFFFF);
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
    colors: [Color(0xFF1C4259), Color(0xFF327A9B)],
  );

  static const LinearGradient sos = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B3850), Color(0xFF7D3038)],
  );

  // ── Badge tints (bg + fg pairs) ─────────────────────────────────────
  // Green stays for "ok": the prototype uses blue for confirmed states,
  // but in a health app green should keep meaning normal/taken.
  static const Color badgeOkBg    = Color(0xFFE5F1EC);
  static Color get badgeOkFg      => _pick(const Color(0xFF2D7F62), const Color(0xFF14503C));
  static const Color badgeWarnBg  = Color(0xFFFFF5DF);
  static Color get badgeWarnFg    => _pick(const Color(0xFF8C6A31), const Color(0xFF5A3F12));
  static const Color badgeRedBg   = Color(0xFFFFF0ED);
  static Color get badgeRedFg     => _pick(const Color(0xFFA14D43), const Color(0xFF7A2A21));
  static const Color badgeBlueBg  = Color(0xFFE6EEF4);
  static Color get badgeBlueFg    => _pick(const Color(0xFF315F74), const Color(0xFF173F52));
  static const Color badgeGrayBg  = Color(0xFFF0F5F9);
  static Color get badgeGrayFg    => _pick(const Color(0xFF717F88), const Color(0xFF2F3B45));

  // ── Component surfaces ──────────────────────────────────────────────
  static const Color calloutBg       = Color(0xFFE6EEF4);
  static const Color calloutWarnBg   = Color(0xFFFFF5DF);
  static const Color calloutDangerBg = Color(0xFFFFF0ED);
  static const Color viewingBorder   = Color(0xFFF1DFB9);
  static const Color searchFill      = Color(0xFFF0F5F9);
  static const Color tabsTrack       = Color(0xFFEDEFF1);
  static Color get progressTrack     => _pick(const Color(0xFFEDEFF1), const Color(0xFFB9C2C8));
  static Color get timelineLine      => _pick(const Color(0xFFDCE6EC), const Color(0xFF6E7B85));
  static const Color timelineRing    = Color(0xFFE6EEF4);
  static const Color avatarBg        = Color(0xFFDCE9EF);
  static const Color avatarDepBg     = Color(0xFFF4DCA9);
  static const Color avatarDepFg     = Color(0xFF3C424C);
  static const Color stepNumBg       = Color(0xFFE6EEF4);
  static const Color stepDoneBg      = Color(0xFFF6F9FA);
  static const Color closeBtnBg      = Color(0xFFF0F5F9);
  static Color get toggleOff         => _pick(const Color(0xFFD5DCE0), const Color(0xFF6E7B85));

  // ── Radii ───────────────────────────────────────────────────────────
  static const double rCard   = 22;
  static const double rHero   = 26;
  static const double rRow    = 15;
  static const double rButton = 12;
  static const double rPill   = 999;
  static const double rModal  = 24;

  // ── Elevation ───────────────────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0C1B2D3F), blurRadius: 36, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> heroShadow = [
    BoxShadow(color: Color(0x1C1D3557), blurRadius: 38, offset: Offset(0, 16)),
  ];
  static const List<BoxShadow> popoverShadow = [
    BoxShadow(color: Color(0x33152535), blurRadius: 60, offset: Offset(0, 22)),
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
  /// How long an animation runs: [normal], or no time at all when she
  /// (or her phone) asked for reduced motion.
  static Duration motion(BuildContext c, Duration normal) =>
      MediaQuery.disableAnimationsOf(c) ? Duration.zero : normal;

  static bool isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < bpMobile;
  static bool isTablet(BuildContext c) => MediaQuery.sizeOf(c).width < bpTablet;

  // ── Type scale ──────────────────────────────────────────────────────
  // Two faces, as in the approved "AfiCare Today" design: Fraunces for
  // page titles, section headings and big numbers; Figtree for
  // everything else (card titles, rows, buttons, labels, body).

  /// Fraunces at the design's weight and tracking. Use for display text
  /// only — never for body copy, rows or buttons.
  static TextStyle serif({required double fontSize, Color? color, double height = 1.15}) =>
      GoogleFonts.fraunces(
          fontSize: fontSize, fontWeight: FontWeight.w500, letterSpacing: -.5, color: color ?? ink, height: height);

  static TextStyle h1() => serif(fontSize: 34, height: 1.13);
  static TextStyle h2() => serif(fontSize: 30, color: white, height: 1.15);

  /// Section headings between cards (`.sectionhead h2`).
  static TextStyle section() => serif(fontSize: 23, height: 1.2);
  static TextStyle h3() => GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700, color: ink);

  static TextStyle eyebrow() =>
      GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: teal);

  static TextStyle sub() => GoogleFonts.figtree(fontSize: 14, color: muted, height: 1.5);
  static TextStyle body() => GoogleFonts.figtree(fontSize: 14, color: ink, height: 1.45);
  static TextStyle rowTitle() => GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700, color: ink);
  static TextStyle rowSub() => GoogleFonts.figtree(fontSize: 12.5, color: muted, height: 1.35);
  static TextStyle label() => GoogleFonts.figtree(fontSize: 12, color: muted);
  static TextStyle metric() => serif(fontSize: 30, color: navy, height: 1.05);
  static TextStyle score() => serif(fontSize: 46, color: navy, height: 1);
  static TextStyle badge() => GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w800);
  static TextStyle button() => GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w700);
  static TextStyle navItem() => GoogleFonts.figtree(fontSize: 15, color: railText);
  static TextStyle navGroup() =>
      GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1, color: const Color(0x80FFFFFF));
}
