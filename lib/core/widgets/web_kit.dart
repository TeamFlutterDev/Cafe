import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'web_layout.dart';

/// Web design kit — the building blocks every desktop-web page is made of, so
/// Bills, Kitchen and the admin masters read as one product rather than seven
/// one-offs. Calm surfaces, hairline borders, one accent (brand orange), text
/// in text colours (never in a series/status colour), status always paired
/// with an icon + label.
///
/// Only the web presentation uses these (see [WebLayout]); native screens keep
/// their existing phone/tablet widgets.
class WebPalette {
  WebPalette._();

  static Color canvas(bool dark) =>
      dark ? AppColors.darkBg : const Color(0xFFF6F7F9);
  static Color surface(bool dark) =>
      dark ? AppColors.darkSurface : Colors.white;
  static Color subtle(bool dark) =>
      dark ? AppColors.darkCard : const Color(0xFFF3F4F6);
  static Color border(bool dark) =>
      dark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
  static Color text(bool dark) =>
      dark ? AppColors.textWhite : const Color(0xFF111827);
  static Color muted(bool dark) =>
      dark ? AppColors.textWhiteMuted : const Color(0xFF6B7280);
  static Color accent(bool dark) =>
      dark ? AppColors.primaryAmber : AppColors.primaryOrange;
}

/// Radii / spacing for web surfaces (multiples of 4).
class WebSpace {
  WebSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double radius = 14;
  static const double radiusSm = 10;
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

// ─── Page frame ──────────────────────────────────────────────────────────────

/// Scrollable page body: gutter padding, content centred and capped at
/// [maxWidth] so a 2560-px monitor doesn't stretch rows edge to edge.
class WebPageBody extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final Future<void> Function()? onRefresh;

  const WebPageBody({
    super.key,
    required this.children,
    this.maxWidth = 1440,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        WebTokens.gutter,
        WebTokens.gutter,
        WebTokens.gutter,
        WebSpace.xxl * 2,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    final refresh = onRefresh;
    return Scrollbar(
      child: refresh == null
          ? list
          : RefreshIndicator(onRefresh: refresh, child: list),
    );
  }
}

/// A row of equal-width children that wraps to fewer columns as the page
/// narrows — never fewer than [minChildWidth] each.
class WebResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double minChildWidth;
  final double spacing;

  const WebResponsiveRow({
    super.key,
    required this.children,
    this.minChildWidth = 220,
    this.spacing = WebSpace.lg,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit =
            ((constraints.maxWidth + spacing) / (minChildWidth + spacing))
                .floor();
        final perRow = fit.clamp(1, children.length);
        final width = (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

// ─── Surfaces ────────────────────────────────────────────────────────────────

/// The standard web surface: white card, hairline border, optional header
/// (title · subtitle · trailing actions) separated by a divider.
class WebCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;

  const WebCard({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.trailing = const [],
    required this.child,
    this.padding = const EdgeInsets.all(WebSpace.xl - 4),
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final hasHeader = title != null || trailing.isNotEmpty;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (hasHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WebSpace.xl - 4,
              WebSpace.lg,
              WebSpace.lg,
              WebSpace.lg,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  WebIconBadge(
                    icon: icon!,
                    color: WebPalette.accent(dark),
                    size: 32,
                  ),
                  const SizedBox(width: WebSpace.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: WebPalette.text(dark),
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: WebPalette.muted(dark),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ...trailing,
              ],
            ),
          ),
        if (hasHeader) Divider(height: 1, color: WebPalette.border(dark)),
        if (height == null)
          Padding(padding: padding, child: child)
        else
          Expanded(
            child: Padding(padding: padding, child: child),
          ),
      ],
    );

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WebPalette.surface(dark),
        borderRadius: BorderRadius.circular(WebSpace.radius),
        border: Border.all(color: WebPalette.border(dark)),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: content,
    );
  }
}

/// Rounded square with a tinted background holding an icon.
class WebIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const WebIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

// ─── KPI tiles ───────────────────────────────────────────────────────────────

/// Headline number tile. The value is in text colour (not the accent); the
/// optional [trend] is a signed % shown with an arrow icon + sign so it never
/// relies on colour alone.
class WebStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final String? caption;
  final double? trend;

  /// Share of a whole (0–1) drawn as a thin bar under the value.
  final double? progress;

  const WebStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.caption,
    this.trend,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final color = accent ?? WebPalette.accent(dark);
    final trend = this.trend;
    final progress = this.progress;

    return Container(
      padding: const EdgeInsets.all(WebSpace.xl - 4),
      decoration: BoxDecoration(
        color: WebPalette.surface(dark),
        borderRadius: BorderRadius.circular(WebSpace.radius),
        border: Border.all(color: WebPalette.border(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: WebPalette.muted(dark),
                  ),
                ),
              ),
              WebIconBadge(icon: icon, color: color, size: 34),
            ],
          ),
          const SizedBox(height: WebSpace.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: WebPalette.text(dark),
              ),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: WebSpace.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 6,
                color: color,
                backgroundColor: WebPalette.subtle(dark),
              ),
            ),
          ],
          if (trend != null || caption != null) ...[
            const SizedBox(height: WebSpace.sm),
            Row(
              children: [
                if (trend != null) ...[
                  _TrendBadge(trend: trend),
                  const SizedBox(width: WebSpace.sm),
                ],
                if (caption != null)
                  Expanded(
                    child: Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: WebPalette.muted(dark),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double trend;
  const _TrendBadge({required this.trend});

  @override
  Widget build(BuildContext context) {
    final up = trend >= 0;
    final color = up ? AppColors.tableFree : AppColors.tableOccupied;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${up ? '+' : ''}${trend.toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status & filters ────────────────────────────────────────────────────────

/// Status label: tinted pill with a leading icon + text (never colour alone).
class WebStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const WebStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One option of a [WebSegmented] control.
class WebSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  final int? count;

  const WebSegment(this.value, this.label, {this.icon, this.count});
}

/// Segmented filter (pill group) — "All · Cash · UPI · Card". Scrolls
/// horizontally when it runs out of room.
class WebSegmented<T> extends StatelessWidget {
  final List<WebSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const WebSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: WebPalette.subtle(dark),
        borderRadius: BorderRadius.circular(WebSpace.radiusSm),
        border: Border.all(color: WebPalette.border(dark)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final s in segments) _segment(context, dark, s)],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, bool dark, WebSegment<T> s) {
    final isSel = s.value == selected;
    final fg = isSel ? WebPalette.text(dark) : WebPalette.muted(dark);
    return Semantics(
      selected: isSel,
      button: true,
      child: Material(
        color: isSel ? WebPalette.surface(dark) : Colors.transparent,
        elevation: isSel && !dark ? 1 : 0,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(WebSpace.radiusSm - 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(WebSpace.radiusSm - 3),
          onTap: () => onChanged(s.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WebSpace.md,
              vertical: 7,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.icon != null) ...[
                  Icon(
                    s.icon,
                    size: 15,
                    color: isSel ? WebPalette.accent(dark) : fg,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  s.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
                if (s.count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSel
                          ? WebPalette.accent(dark).withValues(alpha: 0.12)
                          : WebPalette.border(dark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${s.count}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSel ? WebPalette.accent(dark) : fg,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact search box for toolbars.
class WebSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final double width;

  const WebSearchField({
    super.key,
    this.controller,
    required this.onChanged,
    this.hint = 'Search…',
    this.width = 280,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(WebSpace.radiusSm),
      borderSide: BorderSide(color: WebPalette.border(dark)),
    );
    return SizedBox(
      width: width,
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 13.5, color: WebPalette.text(dark)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            fontSize: 13.5,
            color: WebPalette.muted(dark),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 19,
            color: WebPalette.muted(dark),
          ),
          isDense: true,
          filled: true,
          fillColor: WebPalette.surface(dark),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: WebPalette.accent(dark), width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─── States ──────────────────────────────────────────────────────────────────

/// Centered empty/zero state with an optional call to action.
class WebEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const WebEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WebSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: WebPalette.subtle(dark),
                shape: BoxShape.circle,
                border: Border.all(color: WebPalette.border(dark)),
              ),
              child: Icon(icon, size: 28, color: WebPalette.muted(dark)),
            ),
            const SizedBox(height: WebSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: WebPalette.text(dark),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: WebSpace.xs + 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: WebPalette.muted(dark),
                  ),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: WebSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Master–detail ───────────────────────────────────────────────────────────

/// Right-docked detail panel (editor / inspector) with a header, ✕ close, a
/// scrolling body and an optional sticky footer for actions.
class WebSidePanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onClose;
  final Widget child;
  final List<Widget> footer;
  final double width;

  const WebSidePanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.onClose,
    required this.child,
    this.footer = const [],
    this.width = 520,
  });

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: WebPalette.surface(dark),
        border: Border(left: BorderSide(color: WebPalette.border(dark))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
            blurRadius: 24,
            offset: const Offset(-6, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              WebSpace.xl,
              WebSpace.lg,
              WebSpace.md,
              WebSpace.lg,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: WebPalette.border(dark)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: WebPalette.text(dark),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: WebPalette.muted(dark),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: WebPalette.muted(dark),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
          if (footer.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: WebSpace.xl,
                vertical: WebSpace.md,
              ),
              decoration: BoxDecoration(
                color: WebPalette.surface(dark),
                border: Border(top: BorderSide(color: WebPalette.border(dark))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < footer.length; i++) ...[
                    if (i > 0) const SizedBox(width: WebSpace.sm),
                    footer[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// List on the left, [detail] docked on the right when present. Below
/// [dockBreakpoint] the detail replaces the list instead (not enough room
/// for both).
class WebMasterDetail extends StatelessWidget {
  final Widget master;
  final Widget? detail;
  final double dockBreakpoint;

  const WebMasterDetail({
    super.key,
    required this.master,
    this.detail,
    this.dockBreakpoint = 1100,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final detail = this.detail;
        if (detail == null) return master;
        if (constraints.maxWidth < dockBreakpoint) return detail;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: master),
            detail,
          ],
        );
      },
    );
  }
}

// ─── Dialogs ─────────────────────────────────────────────────────────────────

/// Opens an editor that was designed as a bottom sheet: on web as a centred
/// dialog (a full-width sheet on a 1920-px window reads as a glitch), on
/// native exactly as before via `showModalBottomSheet`.
Future<T?> showAdaptiveEditor<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 560,
}) {
  if (!WebLayout.enabled) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(WebSpace.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(WebSpace.radius + 6),
          child: builder(ctx),
        ),
      ),
    ),
  );
}
