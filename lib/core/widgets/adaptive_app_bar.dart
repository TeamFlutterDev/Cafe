import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'breadcrumbs.dart';
import 'web_layout.dart';

/// Flat, left-aligned desktop page header: title (optionally with a
/// breadcrumb line above it) and right-aligned actions. Never shows a back
/// button — on web, navigation back is the breadcrumb trail's job.
class WebPageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  /// Shown above the title — only for pages outside the signed-in shell (the
  /// shell's top bar already shows the trail for everything inside it).
  final List<Crumb>? crumbs;

  const WebPageHeader({
    super.key,
    required this.title,
    this.actions,
    this.crumbs,
  });

  bool get _hasCrumbs => crumbs?.isNotEmpty ?? false;

  @override
  Size get preferredSize => Size.fromHeight(
    _hasCrumbs
        ? WebTokens.pageHeaderWithCrumbsHeight
        : WebTokens.pageHeaderHeight,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.textWhite : AppColors.textDark;
    final crumbs = this.crumbs;

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Container(
        height: preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: WebTokens.gutter),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: fg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (crumbs != null && crumbs.isNotEmpty) ...[
                      Breadcrumbs(crumbs: crumbs),
                      const SizedBox(height: WebTokens.gap / 2),
                    ],
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: WebTokens.pageTitleFontSize,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              ...?actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// Drop-in `Scaffold.appBar`: the screen's existing [mobile] AppBar on native
/// builds (untouched), a [WebPageHeader] on web. Web actions default to
/// [mobile]'s own `actions`, so screens don't have to list them twice.
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final PreferredSizeWidget mobile;

  /// Overrides the actions shown on web (e.g. to add a labelled primary
  /// button where mobile uses a FAB).
  final List<Widget>? webActions;

  const AdaptiveAppBar({
    super.key,
    required this.title,
    required this.mobile,
    this.webActions,
  });

  List<Widget>? get _actions {
    if (webActions != null) return webActions;
    final bar = mobile;
    return bar is AppBar ? bar.actions : null;
  }

  @override
  Size get preferredSize => WebLayout.enabled
      ? const Size.fromHeight(WebTokens.pageHeaderHeight)
      : mobile.preferredSize;

  @override
  Widget build(BuildContext context) {
    if (!WebLayout.enabled) return mobile;
    return WebPageHeader(title: title, actions: _actions);
  }
}

/// Primary labelled header button used on web where mobile shows a FAB.
class WebHeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const WebHeaderButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: WebTokens.gap),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
