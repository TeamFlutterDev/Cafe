import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'web_layout.dart';

/// One step in a breadcrumb trail. [onTap] null = not clickable (the current
/// page, or a grouping label such as "Admin Masters").
@immutable
class Crumb {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const Crumb(this.label, {this.icon, this.onTap});
}

/// Horizontal "Home › Admin Masters › Item Group › Edit" trail. The last crumb
/// is the current page: bold and never clickable. Scrolls horizontally
/// (anchored to the end, so the current page stays visible) when the trail is
/// wider than the space it's given.
class Breadcrumbs extends StatelessWidget {
  final List<Crumb> crumbs;

  const Breadcrumbs({super.key, required this.crumbs});

  @override
  Widget build(BuildContext context) {
    if (crumbs.isEmpty) return const SizedBox.shrink();
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);

    final children = <Widget>[];
    for (var i = 0; i < crumbs.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WebTokens.gap / 2),
            child: Icon(
              Icons.chevron_right_rounded,
              size: WebTokens.crumbFontSize + 5,
              color: muted,
            ),
          ),
        );
      }
      children.add(
        _CrumbItem(crumb: crumbs[i], isCurrent: i == crumbs.length - 1),
      );
    }

    return Semantics(
      container: true,
      label: 'Breadcrumb',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _CrumbItem extends StatefulWidget {
  final Crumb crumb;
  final bool isCurrent;

  const _CrumbItem({required this.crumb, required this.isCurrent});

  @override
  State<_CrumbItem> createState() => _CrumbItemState();
}

class _CrumbItemState extends State<_CrumbItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final crumb = widget.crumb;
    final tappable = !widget.isCurrent && crumb.onTap != null;

    final color = widget.isCurrent
        ? scheme.onSurface
        : tappable
        ? (_hovered ? scheme.primary : scheme.onSurface.withValues(alpha: 0.65))
        : scheme.onSurface.withValues(alpha: 0.5);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (crumb.icon != null) ...[
          Icon(crumb.icon, size: WebTokens.crumbFontSize + 3, color: color),
          const SizedBox(width: WebTokens.gap / 2),
        ],
        Text(
          crumb.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: WebTokens.crumbFontSize,
            fontWeight: widget.isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: color,
            decoration: tappable && _hovered
                ? TextDecoration.underline
                : TextDecoration.none,
            decorationColor: color,
          ),
        ),
      ],
    );

    if (!tappable) {
      return Semantics(
        // Screen readers announce the current page as such.
        selected: widget.isCurrent,
        child: content,
      );
    }

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: crumb.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: WebTokens.gap / 2),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _Tail {
  final List<Crumb> crumbs;
  final VoidCallback? onBaseTap;

  const _Tail(this.crumbs, this.onBaseTap);

  List<String> get labels => [for (final c in crumbs) c.label];
}

/// Tracks the page stack of one [Navigator] (install it as that navigator's
/// observer) plus any in-page sub-steps screens publish through
/// [BreadcrumbTail], and turns both into a breadcrumb trail.
///
/// Each page route's crumb label is its `RouteSettings.name` — so a pushed
/// screen only needs `settings: RouteSettings(name: 'Variants')` to show up.
/// Dialogs, sheets and menus (non-[PageRoute]s) are ignored.
class BreadcrumbController extends NavigatorObserver with ChangeNotifier {
  final List<Route<dynamic>> _stack = [];
  final Map<Route<dynamic>, _Tail> _tails = {};
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// The page routes currently on the observed navigator, bottom first.
  List<Route<dynamic>> get pageRoutes => [
    for (final r in _stack)
      if (r is PageRoute) r,
  ];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack
      ..remove(route)
      ..add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _drop(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _drop(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (oldRoute != null) _tails.remove(oldRoute);
    if (newRoute == null) {
      if (index >= 0) _stack.removeAt(index);
    } else if (index >= 0) {
      _stack[index] = newRoute;
    } else {
      _stack
        ..remove(newRoute)
        ..add(newRoute);
    }
    _changed();
  }

  void _drop(Route<dynamic> route) {
    _stack.remove(route);
    _tails.remove(route);
    _changed();
  }

  /// Sets the extra crumbs shown after [route]'s own crumb while it is the
  /// top page (e.g. "Edit User"). [onBaseTap] makes [route]'s crumb clickable
  /// while a tail is showing — typically "leave edit mode".
  void setTail(
    Route<dynamic> route,
    List<Crumb> crumbs,
    VoidCallback? onBaseTap,
  ) {
    if (crumbs.isEmpty) {
      clearTail(route);
      return;
    }
    final old = _tails[route];
    _tails[route] = _Tail(List.unmodifiable(crumbs), onBaseTap);
    final changed =
        old == null ||
        !listEquals(old.labels, _tails[route]?.labels) ||
        (old.onBaseTap == null) != (onBaseTap == null);
    if (changed) _changed();
  }

  void clearTail(Route<dynamic> route) {
    if (_tails.remove(route) != null) _changed();
  }

  /// The full trail: [leading] (e.g. Home › section), then one crumb per page
  /// route, then the top page's tail. Every crumb except the current one pops
  /// back to its page on tap.
  List<Crumb> trail({List<Crumb> leading = const []}) {
    final routes = pageRoutes;
    final out = <Crumb>[...leading];
    for (var i = 0; i < routes.length; i++) {
      final route = routes[i];
      final isTop = i == routes.length - 1;
      final tail = isTop ? _tails[route] : null;

      // Tail callbacks are looked up at tap time, not captured here: the page
      // re-registers fresh closures on every rebuild, but the trail is only
      // rebuilt when the *labels* change.
      VoidCallback? onTap;
      if (!isTop) {
        onTap = () => navigator?.popUntil((r) => r == route);
      } else if (tail?.onBaseTap != null) {
        onTap = () => _tails[route]?.onBaseTap?.call();
      }
      out.add(Crumb(route.settings.name ?? 'Details', onTap: onTap));
      if (tail != null) {
        for (var j = 0; j < tail.crumbs.length; j++) {
          final c = tail.crumbs[j];
          out.add(
            Crumb(
              c.label,
              icon: c.icon,
              onTap: c.onTap == null
                  ? null
                  : () {
                      final current = _tails[route]?.crumbs;
                      if (current != null && j < current.length) {
                        current[j].onTap?.call();
                      }
                    },
            ),
          );
        }
      }
    }
    return out;
  }

  /// Observer callbacks fire mid-build/mid-navigation; listeners rebuild UI,
  /// so every change is coalesced into one notification after the frame.
  void _changed() {
    if (_disposed || _notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Exposes the shell's [BreadcrumbController] to the pages of its content
/// navigator. Absent on native builds and outside the signed-in web shell.
class BreadcrumbScope extends InheritedWidget {
  final BreadcrumbController controller;

  const BreadcrumbScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static BreadcrumbController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BreadcrumbScope>()?.controller;

  @override
  bool updateShouldNotify(BreadcrumbScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Lets a page add in-page steps after its own crumb — e.g. User Master's
/// editor: "User Master › Edit User", where tapping "User Master" runs
/// [onBaseTap] (close the editor). A no-op wrapper when there is no
/// [BreadcrumbScope] (native builds), so screens can use it unconditionally.
class BreadcrumbTail extends StatefulWidget {
  final List<Crumb> crumbs;
  final VoidCallback? onBaseTap;
  final Widget child;

  const BreadcrumbTail({
    super.key,
    required this.crumbs,
    this.onBaseTap,
    required this.child,
  });

  @override
  State<BreadcrumbTail> createState() => _BreadcrumbTailState();
}

class _BreadcrumbTailState extends State<BreadcrumbTail> {
  BreadcrumbController? _controller;
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = BreadcrumbScope.maybeOf(context);
    final route = ModalRoute.of(context);
    if (controller != _controller || route != _route) {
      final oldRoute = _route;
      if (oldRoute != null) _controller?.clearTail(oldRoute);
      _controller = controller;
      _route = route;
    }
  }

  @override
  void dispose() {
    final route = _route;
    if (route != null) _controller?.clearTail(route);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    if (route != null) {
      _controller?.setTail(route, widget.crumbs, widget.onBaseTap);
    }
    return widget.child;
  }
}
