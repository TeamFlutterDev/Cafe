import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'window_class.dart';

/// Single switch for the Flutter **web** presentation: breadcrumbs instead of
/// back buttons, a persistent sidebar shell with its own content navigator,
/// and flat desktop-style page headers. Native (Android/iOS/desktop) builds
/// never see any of it — they keep the drawer + AppBar back-button UI.
///
/// Keyed on the platform rather than the window width on purpose: resizing a
/// browser window must not tear down the shell's content navigator (and with
/// it every open page's state). Width still drives drawer-vs-sidebar inside
/// the web shell via [WindowClassX.isWideWindow].
class WebLayout {
  WebLayout._();

  /// Lets widget tests exercise the web presentation on the VM.
  @visibleForTesting
  static bool? debugOverride;

  static bool get enabled => debugOverride ?? kIsWeb;
}

/// Spacing/size tokens for the web chrome (top bar, sidebar, page headers).
class WebTokens {
  WebTokens._();

  static const double topBarHeight = 56;
  static const double pageHeaderHeight = 64;
  static const double pageHeaderWithCrumbsHeight = 84;
  static const double sidebarWidth = 264;
  static const double gutter = 24;
  static const double gap = 8;
  static const double crumbFontSize = 13;
  static const double pageTitleFontSize = 20;
}

extension WebLayoutX on BuildContext {
  /// Whether a screen should draw its own ☰ button. On web the shell's top
  /// bar owns that button; on native it only appears without a permanent
  /// sidebar.
  bool get showScreenMenuButton => !WebLayout.enabled && !isWideWindow;
}
