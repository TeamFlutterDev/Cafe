import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'web_kit.dart';

/// One row of the [WebSidebar]: a group label or a destination.
sealed class WebSideEntry {
  const WebSideEntry();
}

/// "MASTERS", "OPERATIONS"… — collapses to a hairline in rail mode.
class WebSideSection extends WebSideEntry {
  final String label;
  const WebSideSection(this.label);
}

class WebSideItem extends WebSideEntry {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const WebSideItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
}

/// Widths of the two sidebar states.
class WebSidebarSize {
  WebSidebarSize._();

  static const double expanded = 264;
  static const double rail = 76;

  /// Below this rendered width the rail layout is used (also mid-animation,
  /// so labels never get squeezed while the width animates).
  static const double railBelow = 180;

  static const Duration animation = Duration(milliseconds: 220);
}

/// Web side menu: brand header with a collapse button, grouped destinations
/// with icon tiles, and a Logout button pinned to the bottom. Renders as a
/// labelled panel when wide, or an icon-only rail (labels as tooltips) when
/// its parent gives it less than [WebSidebarSize.railBelow].
class WebSidebar extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData brandIcon;
  final List<WebSideEntry> entries;
  final VoidCallback onToggle;
  final IconData toggleIcon;
  final String toggleTooltip;
  final VoidCallback onLogout;

  const WebSidebar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.onToggle,
    required this.onLogout,
    this.brandIcon = Icons.restaurant_rounded,
    this.toggleIcon = Icons.menu_open_rounded,
    this.toggleTooltip = 'Collapse menu',
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: WebPalette.surface(dark),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rail = constraints.maxWidth < WebSidebarSize.railBelow;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(dark, rail),
              Divider(height: 1, color: WebPalette.border(dark)),
              Expanded(
                child: Scrollbar(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: WebSpace.sm),
                    children: [for (final e in entries) _entry(dark, rail, e)],
                  ),
                ),
              ),
              Divider(height: 1, color: WebPalette.border(dark)),
              _logout(dark, rail),
            ],
          );
        },
      ),
    );
  }

  Widget _brandTile() => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primaryAmber, AppColors.primaryOrange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryOrange.withValues(alpha: 0.25),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Icon(brandIcon, color: Colors.white, size: 20),
  );

  Widget _header(bool dark, bool rail) {
    if (rail) {
      // Tapping the brand in rail mode expands the menu again.
      return SizedBox(
        height: 72,
        child: Center(
          child: Tooltip(
            message: toggleTooltip,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onToggle,
              child: _brandTile(),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(WebSpace.lg, 0, WebSpace.md, 0),
        child: Row(
          children: [
            _brandTile(),
            const SizedBox(width: WebSpace.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: WebPalette.text(dark),
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: WebPalette.muted(dark),
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: toggleTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onToggle,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: WebPalette.subtle(dark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: WebPalette.border(dark)),
                  ),
                  child: Icon(
                    toggleIcon,
                    size: 19,
                    color: WebPalette.muted(dark),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entry(bool dark, bool rail, WebSideEntry e) {
    return switch (e) {
      WebSideSection(:final label) =>
        rail
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: WebSpace.md,
                ),
                child: Divider(height: 1, color: WebPalette.border(dark)),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: WebPalette.muted(dark),
                  ),
                ),
              ),
      final WebSideItem item => _item(dark, rail, item),
    };
  }

  Widget _item(bool dark, bool rail, WebSideItem item) {
    final accent = WebPalette.accent(dark);
    final sel = item.selected;
    final tile = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: sel ? accent.withValues(alpha: 0.14) : WebPalette.subtle(dark),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        item.icon,
        size: 18,
        color: sel ? accent : WebPalette.muted(dark),
      ),
    );

    final row = Material(
      color: sel ? accent.withValues(alpha: 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        hoverColor: accent.withValues(alpha: 0.05),
        onTap: item.onTap,
        child: SizedBox(
          height: 46,
          child: rail
              ? Center(child: tile)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      tile,
                      const SizedBox(width: WebSpace.md),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? accent : WebPalette.text(dark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rail ? 12 : 10, vertical: 2),
      child: Semantics(
        selected: sel,
        button: true,
        label: rail ? item.label : null,
        child: rail ? Tooltip(message: item.label, child: row) : row,
      ),
    );
  }

  Widget _logout(bool dark, bool rail) {
    final red = AppColors.error;
    final button = Material(
      color: red.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onLogout,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: red.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 18, color: red),
              if (!rail) ...[
                const SizedBox(width: WebSpace.sm),
                Text(
                  'Logout',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.all(rail ? 12 : WebSpace.md),
      child: rail ? Tooltip(message: 'Logout', child: button) : button,
    );
  }
}

/// Round ‹ / › button that sits on the sidebar's right border.
class WebSidebarEdgeToggle extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onPressed;

  const WebSidebarEdgeToggle({
    super.key,
    required this.collapsed,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: collapsed ? 'Expand menu' : 'Collapse menu',
      child: Material(
        color: WebPalette.surface(dark),
        shape: CircleBorder(side: BorderSide(color: WebPalette.border(dark))),
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 26,
            height: 26,
            child: Icon(
              collapsed
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              size: 18,
              color: WebPalette.muted(dark),
            ),
          ),
        ),
      ),
    );
  }
}
