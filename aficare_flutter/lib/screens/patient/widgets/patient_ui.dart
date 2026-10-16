import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../theme/patient_tokens.dart';
import '../patient_nav.dart';

/// The patient app's shared visual vocabulary, transcribed from
/// `docs/patient_prototype.html`. Every widget here maps to one class in
/// that spec, so a screen is assembled from these rather than
/// re-inventing cards, rows and badges (which is how the patient screens
/// drifted apart in the first place).
///
/// These are presentation-only: they take primitives and callbacks, never
/// providers, so they can be used by both the provider-driven screens and
/// the screen-local ones.

// ═══════════════════════════════════════════════════════════════════════
// Screen scaffold — `.screen` + `.head`
// ═══════════════════════════════════════════════════════════════════════

class PScreen extends StatelessWidget {
  const PScreen({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.action,
    required this.children,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PScreenHead(eyebrow: eyebrow, title: title, subtitle: subtitle, action: action),
        ...children,
      ],
    );
  }
}

class PScreenHead extends StatelessWidget {
  const PScreenHead({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(), style: PT.eyebrow()),
        const SizedBox(height: 5),
        Text(title, style: PT.h1()),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(subtitle!, style: PT.sub()),
        ],
      ],
    );

    if (action == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 20), child: text);
    }

    // The spec wraps the head below 700px rather than squeezing the
    // action button against the title.
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: PT.isMobile(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 15), action!],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: text),
                const SizedBox(width: 15),
                action!,
              ],
            ),
    );
  }
}

/// Marks everything below it as rendered inside the patient shell (the
/// sidebar, top bar and bottom bar are already on screen), and carries
/// the shell's load state down to the pages.
class PatientShellScope extends InheritedWidget {
  const PatientShellScope({
    super.key,
    required this.loadFailed,
    required this.onRetry,
    required super.child,
  });

  /// True when the shell's initial load of the patient's data failed.
  final bool loadFailed;
  final VoidCallback onRetry;

  static PatientShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PatientShellScope>();

  static bool inShell(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PatientShellScope>() != null;

  @override
  bool updateShouldNotify(PatientShellScope old) => old.loadFailed != loadFailed;
}

/// The design's `.backlink`: "← Back to More of AfiCare" at the foot of a
/// page reached from the More page.
///
/// A page pushed on top of another (a detail view opened with
/// Navigator.push) gets a plain "← Back" that returns to it instead. A
/// sidebar destination gets nothing — the sidebar is the way out.
class PBackLink extends StatelessWidget {
  const PBackLink({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    // GoRouter pages carry a Page as their settings; anything else was
    // pushed imperatively over a page and should simply pop.
    final pushed = route != null && route.settings is! Page && Navigator.of(context).canPop();

    final String label;
    final VoidCallback action;
    if (onBack != null) {
      label = '← Back';
      action = onBack!;
    } else if (pushed) {
      label = '← Back';
      action = () => Navigator.of(context).pop();
    } else {
      final String location;
      try {
        location = GoRouterState.of(context).uri.path;
      } catch (_) {
        return const SizedBox.shrink();
      }
      if (isPatientSidebarRoute(location)) return const SizedBox.shrink();
      label = '← Back to More of AfiCare';
      action = () => context.go(PatientRoutes.more);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Align(
        alignment: Alignment.centerLeft,
        child: PButton(label, kind: PButtonKind.alt, onPressed: action),
      ),
    );
  }
}

/// The chrome every patient page shares.
///
/// Inside the shell (the normal case) it is just the page: the design's
/// eyebrow/title/subtitle head, the content and a [PBackLink]. Outside it
/// — a page opened on its own, which should now be rare — it adds the
/// page ground and a minimal back bar so the page is never a dead end.
class PDetailScaffold extends StatelessWidget {
  const PDetailScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.action,
    required this.children,
    this.onBack,
    this.floatingActionButton,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;
  final VoidCallback? onBack;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final page = PScreen(
      eyebrow: eyebrow,
      title: title,
      subtitle: subtitle,
      action: action,
      children: [...children, PBackLink(onBack: onBack)],
    );

    if (PatientShellScope.inShell(context)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: floatingActionButton,
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: page,
        ),
      );
    }

    return Scaffold(
      backgroundColor: PT.page,
      floatingActionButton: floatingActionButton,
      appBar: _standaloneBar(context, onBack),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PT.maxContentWidth),
            child: page,
          ),
        ),
      ),
    );
  }
}

/// [PDetailScaffold] for pages built from slivers (long lists, pinned
/// sections). Same head, same back link, same shell awareness.
class PSliverPage extends StatelessWidget {
  const PSliverPage({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.action,
    required this.slivers,
    this.onBack,
    this.floatingActionButton,
    this.controller,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> slivers;
  final VoidCallback? onBack;
  final Widget? floatingActionButton;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final inShell = PatientShellScope.inShell(context);
    final scroll = CustomScrollView(
      controller: controller,
      slivers: [
        SliverToBoxAdapter(
          child: PScreenHead(eyebrow: eyebrow, title: title, subtitle: subtitle, action: action),
        ),
        ...slivers,
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: PBackLink(onBack: onBack),
          ),
        ),
      ],
    );

    if (inShell) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: floatingActionButton,
        body: scroll,
      );
    }

    return Scaffold(
      backgroundColor: PT.page,
      floatingActionButton: floatingActionButton,
      appBar: _standaloneBar(context, onBack),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PT.maxContentWidth),
            child: scroll,
          ),
        ),
      ),
    );
  }
}

/// Header for a sub-page whose body is its own scrolling list (a form,
/// a settings list, a detail view opened from another page): a back arrow
/// and the title in the design's serif, on the page ground rather than a
/// coloured app bar. Use as a Scaffold's `appBar:` with a transparent
/// Scaffold so it sits inside the shell's content area.
class PSubPageBar extends StatelessWidget implements PreferredSizeWidget {
  const PSubPageBar({super.key, required this.title, this.onBack, this.actions = const []});

  final String title;

  /// Defaults to popping back to the page this was opened from, or to the
  /// More page when there is nothing to pop (a deep link or a refresh).
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack ??
                () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go(PatientRoutes.more);
                  }
                },
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            style: IconButton.styleFrom(
              fixedSize: const Size(42, 42),
              backgroundColor: PT.white,
              foregroundColor: PT.teal,
              side: const BorderSide(color: PT.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: PT.serif(fontSize: 27), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A patient page that is still loading. Inside the shell that is just a
/// spinner where the page will be; on its own it also paints the ground.
class PLoadingPage extends StatelessWidget {
  const PLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    const spinner = Center(child: CircularProgressIndicator(color: PT.teal));
    if (PatientShellScope.inShell(context)) return spinner;
    return const Scaffold(backgroundColor: PT.page, body: spinner);
  }
}

/// Minimal back bar for a page shown outside the shell. Falls back to
/// Today when there is nothing to pop to (a deep link or a refresh).
PreferredSizeWidget _standaloneBar(BuildContext context, VoidCallback? onBack) {
  return AppBar(
    backgroundColor: PT.page,
    surfaceTintColor: PT.page,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: PT.ink),
      onPressed: onBack ??
          () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(PatientRoutes.today);
            }
          },
    ),
  );
}

/// Plain section heading used above a list inside a screen (not a card).
class PHeading extends StatelessWidget {
  const PHeading(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: PT.section())),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Hero — `.hero`
// ═══════════════════════════════════════════════════════════════════════

class PHero extends StatelessWidget {
  const PHero({
    super.key,
    required this.title,
    this.chip,
    this.body,
    this.action,
    this.trailing,
  });

  final String title;
  final String? chip;
  final String? body;
  final Widget? action;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 175),
      margin: const EdgeInsets.only(bottom: 17),
      padding: const EdgeInsets.all(27),
      decoration: BoxDecoration(
        gradient: PT.hero,
        borderRadius: BorderRadius.circular(PT.rHero),
        boxShadow: PT.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (chip != null) ...[PChip(chip!), const SizedBox(height: 9)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: PT.h2().copyWith(fontSize: PT.isMobile(context) ? 29 : 36),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 9),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Text(
                body!,
                style: PT.body().copyWith(color: Colors.white.withOpacity(.85)),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

class PChip extends StatelessWidget {
  const PChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x1CFFFFFF),
        borderRadius: BorderRadius.circular(PT.rPill),
      ),
      child: Text(label, style: PT.badge().copyWith(color: Colors.white)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Cards — `.card`, `.title`, `.metric`
// ═══════════════════════════════════════════════════════════════════════

class PCard extends StatelessWidget {
  const PCard({super.key, required this.child, this.padding, this.color});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: color ?? PT.white,
        border: Border.all(color: PT.line),
        borderRadius: BorderRadius.circular(PT.rCard),
        boxShadow: PT.cardShadow,
      ),
      child: child,
    );
  }
}

class PCardTitle extends StatelessWidget {
  const PCardTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(child: Text(title, style: PT.h3())),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class PMetric extends StatelessWidget {
  const PMetric({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.valueFontSize,
    this.onTap,
  });

  final String label;
  final String value;
  final String? note;
  final double? valueFontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PT.label()),
        const SizedBox(height: 7),
        Text(
          value,
          style: valueFontSize == null ? PT.metric() : PT.metric().copyWith(fontSize: valueFontSize),
        ),
        if (note != null) ...[
          const SizedBox(height: 7),
          Text(note!, style: PT.body().copyWith(color: PT.green, fontWeight: FontWeight.w600)),
        ],
      ],
    );

    return PCard(
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(PT.rRow),
              child: content,
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Rows — `.row`
// ═══════════════════════════════════════════════════════════════════════

class PRow extends StatelessWidget {
  const PRow({
    super.key,
    this.leading,
    this.leadingEmoji,
    required this.title,
    this.subtitle,
    this.extraSubtitle,
    this.trailing = const [],
    this.below,
    this.onTap,
  });

  final Widget? leading;
  final String? leadingEmoji;
  final String title;
  final String? subtitle;
  final String? extraSubtitle;
  final List<Widget> trailing;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget? lead = leading;
    lead ??= leadingEmoji == null ? null : Text(leadingEmoji!, style: const TextStyle(fontSize: 19));

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (lead != null) ...[lead, const SizedBox(width: 11)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: PT.rowTitle()),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: PT.rowSub()),
                  ],
                  if (extraSubtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(extraSubtitle!, style: PT.rowSub()),
                  ],
                ],
              ),
            ),
            for (final t in trailing) ...[const SizedBox(width: 11), t],
          ],
        ),
        if (below != null) ...[const SizedBox(height: 8), below!],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PT.rRow),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: PT.line),
              borderRadius: BorderRadius.circular(PT.rRow),
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Badges — `.badge` + tones
// ═══════════════════════════════════════════════════════════════════════

enum PTone { ok, warn, red, blue, gray }

class PBadge extends StatelessWidget {
  const PBadge(this.label, {super.key, this.tone = PTone.ok});

  final String label;
  final PTone tone;

  static (Color, Color) colorsFor(PTone tone) => switch (tone) {
        PTone.ok => (PT.badgeOkBg, PT.badgeOkFg),
        PTone.warn => (PT.badgeWarnBg, PT.badgeWarnFg),
        PTone.red => (PT.badgeRedBg, PT.badgeRedFg),
        PTone.blue => (PT.badgeBlueBg, PT.badgeBlueFg),
        PTone.gray => (PT.badgeGrayBg, PT.badgeGrayFg),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsFor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(PT.rPill)),
      child: Text(label, style: PT.badge().copyWith(color: fg)),
    );
  }
}

/// A [PBadge] with a remove button, for lists the person is editing
/// (allergies, medicines to compare).
class PRemovableBadge extends StatelessWidget {
  const PRemovableBadge(this.label, {super.key, required this.onRemove, this.tone = PTone.blue});

  final String label;
  final VoidCallback onRemove;
  final PTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = PBadge.colorsFor(tone);
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 3, bottom: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(PT.rPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: PT.badge().copyWith(color: fg, fontSize: 12)),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.close_rounded, size: 15, color: fg, semanticLabel: 'Remove $label'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Buttons — `.btn`, `.btn.alt`, `.btn.red`
// ═══════════════════════════════════════════════════════════════════════

enum PButtonKind { primary, alt, red }

class PButton extends StatelessWidget {
  const PButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = PButtonKind.primary,
    this.icon,
    this.dense = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PButtonKind kind;
  final IconData? icon;
  final bool dense;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bg = switch (kind) {
      PButtonKind.primary => PT.navy,
      PButtonKind.alt => PT.white,
      PButtonKind.red => PT.danger,
    };
    final fg = kind == PButtonKind.alt ? PT.navy : PT.white;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 17, color: fg), const SizedBox(width: 7)],
        // Flexible so a long label wraps on a narrow phone instead of
        // overflowing the button.
        Flexible(
          child: Text(label,
              textAlign: TextAlign.center, style: PT.button().copyWith(color: fg, fontSize: dense ? 12 : 14)),
        ),
      ],
    );

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(PT.rButton),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: dense
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: kind == PButtonKind.alt
              ? BoxDecoration(
                  border: Border.all(color: PT.line),
                  borderRadius: BorderRadius.circular(PT.rButton),
                )
              : null,
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Responsive grid — `.grid`/`.g2`/`.g3`/`.g4`
// ═══════════════════════════════════════════════════════════════════════

class PGrid extends StatelessWidget {
  const PGrid({super.key, required this.columns, required this.children, this.gap = 16});

  final int columns;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final cols = PT.isMobile(context)
        ? 1
        : PT.isTablet(context)
            ? (columns >= 3 ? 2 : columns)
            : columns;

    if (cols == 1) {
      return Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) SizedBox(height: gap),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += cols) {
      final slice = children.sublist(i, (i + cols).clamp(0, children.length));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int j = 0; j < cols; j++) ...[
            Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()),
            if (j < cols - 1) SizedBox(width: gap),
          ],
        ],
      ));
      if (i + cols < children.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Quick actions — `.quick` (stays 2-up at every width per the spec)
// ═══════════════════════════════════════════════════════════════════════

class PQuickAction {
  const PQuickAction({required this.emoji, required this.label, required this.note, required this.onTap});

  final String emoji;
  final String label;
  final String note;
  final VoidCallback onTap;
}

class PQuickActions extends StatelessWidget {
  const PQuickActions(this.actions, {super.key});

  final List<PQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < actions.length; i += 2) {
      final a = actions[i];
      final b = i + 1 < actions.length ? actions[i + 1] : null;
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _tile(a)),
          const SizedBox(width: 10),
          Expanded(child: b == null ? const SizedBox.shrink() : _tile(b)),
        ],
      ));
      if (i + 2 < actions.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _tile(PQuickAction a) {
    return Material(
      color: PT.white,
      borderRadius: BorderRadius.circular(PT.rRow),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: a.onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border.all(color: PT.line),
            borderRadius: BorderRadius.circular(PT.rRow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${a.emoji} ${a.label}',
                  style: PT.body().copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(a.note, style: PT.rowSub()),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Soft icon — `.soft-icon` (the tinted tile that leads most rows)
// ═══════════════════════════════════════════════════════════════════════

class PSoftIcon extends StatelessWidget {
  const PSoftIcon(this.icon, {super.key, this.size = 42});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: PT.calloutBg, borderRadius: BorderRadius.circular(size / 3)),
      child: Icon(icon, size: size * .47, color: PT.teal),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Avatar — `.avatar` / `.avatar.dep`
// ═══════════════════════════════════════════════════════════════════════

class PAvatar extends StatelessWidget {
  const PAvatar({
    super.key,
    required this.initials,
    this.size = 35,
    this.isDependent = false,
    this.photoUrl,
  });

  final String initials;
  final double size;
  final bool isDependent;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDependent ? PT.avatarDepBg : PT.avatarBg,
        image: hasPhoto ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover) : null,
      ),
      child: hasPhoto
          ? null
          : Text(
              initials,
              style: PT.body().copyWith(
                fontWeight: FontWeight.w800,
                color: isDependent ? PT.avatarDepFg : PT.navy,
                fontSize: size * .4,
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Empty state — `.empty`
// ═══════════════════════════════════════════════════════════════════════

class PEmpty extends StatelessWidget {
  const PEmpty({super.key, required this.emoji, required this.title, this.body, this.action});

  final String emoji;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          Text(title, style: PT.h3(), textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(body!, textAlign: TextAlign.center, style: PT.sub()),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Callout — `.callout` / `.warn` / `.danger`
// ═══════════════════════════════════════════════════════════════════════

class PCallout extends StatelessWidget {
  const PCallout({super.key, this.title, required this.body, this.tone = PTone.ok, this.trailing});

  final String? title;
  final String body;
  final PTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      PTone.warn => PT.calloutWarnBg,
      PTone.red => PT.calloutDangerBg,
      _ => PT.calloutBg,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(PT.rRow)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: PT.body().copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                ],
                Text(body, style: PT.sub().copyWith(color: const Color(0xFF5D7179))),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Progress — `.progress`
// ═══════════════════════════════════════════════════════════════════════

/// Shown when a load failed, so that a failed query never masquerades as
/// an empty record. A patient who is told "no medications yet" when the
/// request simply didn't arrive may conclude they have nothing to take,
/// so every screen that can come back empty must be able to say this
/// instead — and must suppress its empty state while it does.
class PLoadError extends StatelessWidget {
  const PLoadError({super.key, required this.what, required this.onRetry});

  /// What could not be loaded, in the patient's own words — e.g.
  /// "your medications", which reads as "Could not load your medications".
  final String what;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PCallout(
      title: 'Could not load $what',
      body: "You may be offline. Nothing has been lost — check your connection and try again.",
      tone: PTone.red,
      trailing: PButton('Retry', kind: PButtonKind.alt, dense: true, onPressed: onRetry),
    );
  }
}

/// Shown above data that came from the on-device copy because the live
/// load failed. It must never be silent: showing a saved list as though
/// it were current is its own kind of lie, just a gentler one.
class POfflineBanner extends StatelessWidget {
  const POfflineBanner({super.key, required this.savedAt, this.onRetry});

  final DateTime savedAt;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return PCallout(
      title: 'Showing your saved copy',
      body: "You appear to be offline. This is what we last saved on ${_when(savedAt)} — "
          'anything added since then is not here.',
      tone: PTone.warn,
      trailing: onRetry == null
          ? null
          : PButton('Retry', kind: PButtonKind.alt, dense: true, onPressed: onRetry),
    );
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    final days = today.difference(that).inDays;
    final time = DateFormat('HH:mm').format(t);
    if (days == 0) return 'today at $time';
    if (days == 1) return 'yesterday at $time';
    if (days < 7) return '${DateFormat('EEEE').format(t)} at $time';
    return DateFormat('d MMMM').format(t);
  }
}

class PProgress extends StatelessWidget {
  const PProgress(this.value, {super.key, this.color, this.height = 9});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PT.rPill),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: PT.progressTrack,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? PT.teal),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tabs — `.tabs`
// ═══════════════════════════════════════════════════════════════════════

class PTabs extends StatelessWidget {
  const PTabs({super.key, required this.tabs, required this.selected, required this.onSelect});

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: PT.tabsTrack,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (int i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Material(
                  color: i == selected ? PT.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => onSelect(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      child: Text(
                        tabs[i],
                        style: PT.body().copyWith(
                          color: i == selected ? PT.navy : PT.muted,
                          fontWeight: i == selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Timeline — `.timeline` / `.event`
// ═══════════════════════════════════════════════════════════════════════

class PTimelineEvent {
  const PTimelineEvent({required this.title, this.subtitle});

  final String title;
  final String? subtitle;
}

class PTimeline extends StatelessWidget {
  const PTimeline(this.events, {super.key});

  final List<PTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      if (i < events.length - 1)
                        Positioned(
                          top: 12,
                          bottom: 0,
                          child: Container(width: 2, color: PT.timelineLine),
                        ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: PT.teal,
                          border: Border.all(color: PT.timelineRing, width: 3),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < events.length - 1 ? 18 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(events[i].title, style: PT.rowTitle()),
                        if (events[i].subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(events[i].subtitle!, style: PT.rowSub()),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Score — `.score`
// ═══════════════════════════════════════════════════════════════════════

class PScore extends StatelessWidget {
  const PScore({super.key, required this.label, required this.value, this.badge});

  final String label;
  final String value;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return PCard(
      child: Column(
        children: [
          Text(label, style: PT.label()),
          const SizedBox(height: 4),
          Text(value, style: PT.score()),
          if (badge != null) ...[const SizedBox(height: 6), badge!],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SOS banner — `.sos`
// ═══════════════════════════════════════════════════════════════════════

class PSosBanner extends StatelessWidget {
  const PSosBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.action,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(),
            style: PT.eyebrow().copyWith(color: const Color(0xFFFFD9DC))),
        const SizedBox(height: 6),
        Text(title, style: PT.h2()),
        const SizedBox(height: 6),
        Text(body, style: PT.body().copyWith(color: Colors.white.withOpacity(.85))),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: PT.sos,
        borderRadius: BorderRadius.circular(PT.rHero),
      ),
      child: PT.isMobile(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 20), action],
            )
          : Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 20),
                action,
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Guardian mode banner — `.viewing`
// ═══════════════════════════════════════════════════════════════════════

class PViewingBanner extends StatelessWidget {
  const PViewingBanner({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: PT.calloutWarnBg,
        border: Border.all(color: PT.viewingBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('👀', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: PT.sub().copyWith(color: PT.ink))),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Onboarding step — `.step` / `.step.done` / `.step.opt`
// ═══════════════════════════════════════════════════════════════════════

class PStepRow extends StatelessWidget {
  const PStepRow({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    this.done = false,
    this.action,
  });

  final int number;
  final String title;
  final String? subtitle;
  final bool done;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? PT.stepDoneBg : PT.white,
          border: Border.all(color: PT.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? PT.teal : PT.stepNumBg,
              ),
              child: done
                  ? const Icon(Icons.check, size: 17, color: Colors.white)
                  : Text('$number',
                      style: PT.body().copyWith(fontWeight: FontWeight.w900, color: PT.teal)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PT.rowTitle().copyWith(
                      color: done ? PT.muted : PT.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: PT.rowSub()),
                  ],
                ],
              ),
            ),
            if (action != null && !done) ...[const SizedBox(width: 10), action!],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Toggle — `.sw`
// ═══════════════════════════════════════════════════════════════════════

class PToggle extends StatelessWidget {
  const PToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value ? PT.teal : PT.toggleOff,
          borderRadius: BorderRadius.circular(PT.rPill),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(3),
                width: 20,
                height: 20,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Modal + form — `.modal`, `.form`, `.field`
// ═══════════════════════════════════════════════════════════════════════

Future<T?> showPModal<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext) builder,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: PT.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PT.rModal)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(ctx).size.height * .9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: PT.serif(fontSize: 24))),
                  Material(
                    color: PT.closeBtnBg,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => Navigator.pop(ctx),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(Icons.close, size: 18, color: PT.muted),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              builder(ctx),
            ],
          ),
        ),
      ),
    ),
  );
}

/// `.form` — two columns, collapsing to one below the mobile breakpoint.
class PFormGrid extends StatelessWidget {
  const PFormGrid(this.fields, {super.key});

  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return PGrid(columns: 2, gap: 11, children: fields);
  }
}

class PField extends StatelessWidget {
  const PField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PT.label().copyWith(fontSize: 11)),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

InputDecoration pInput({String? hint}) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: PT.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      hintStyle: PT.sub(),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PT.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PT.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PT.teal, width: 1.5),
      ),
    );

// ═══════════════════════════════════════════════════════════════════════
// Toast — `.toast`
// ═══════════════════════════════════════════════════════════════════════

void pToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: PT.body().copyWith(color: Colors.white)),
      backgroundColor: PT.navy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(milliseconds: 2300),
    ),
  );
}
