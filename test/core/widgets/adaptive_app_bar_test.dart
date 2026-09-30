import 'package:cafe/core/widgets/adaptive_app_bar.dart';
import 'package:cafe/core/widgets/breadcrumbs.dart';
import 'package:cafe/core/widgets/web_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pushes a page using [AdaptiveAppBar] on top of a home page, so the mobile
/// AppBar would normally show an automatic back button.
Future<void> _pumpPushedPage(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AdaptiveAppBar(
                    title: 'Table Master',
                    mobile: AppBar(
                      title: const Text('Table Master'),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  body: const SizedBox.shrink(),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => WebLayout.debugOverride = null);

  testWidgets('native: keeps the original AppBar with its back button', (
    tester,
  ) async {
    WebLayout.debugOverride = false;
    await _pumpPushedPage(tester);

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(WebPageHeader), findsNothing);
  });

  testWidgets('web: flat header, no back button, same actions', (tester) async {
    WebLayout.debugOverride = true;
    await _pumpPushedPage(tester);

    expect(find.byType(WebPageHeader), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Table Master'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('web: webActions replace the mobile actions', (tester) async {
    WebLayout.debugOverride = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AdaptiveAppBar(
            title: 'Raw Materials',
            webActions: [
              WebHeaderButton(
                icon: Icons.add_rounded,
                label: 'Add Material',
                onPressed: () {},
              ),
            ],
            mobile: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Add Material'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });

  testWidgets('preferredSize follows the active presentation', (tester) async {
    final bar = AdaptiveAppBar(
      title: 'X',
      mobile: AppBar(
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox.shrink(),
        ),
      ),
    );

    WebLayout.debugOverride = false;
    expect(bar.preferredSize.height, kToolbarHeight + 1);

    WebLayout.debugOverride = true;
    expect(bar.preferredSize.height, WebTokens.pageHeaderHeight);
  });

  testWidgets('WebPageHeader shows breadcrumbs above the title when given', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: WebPageHeader(
            title: 'Verify OTP',
            crumbs: [Crumb('Sign in'), Crumb('Verify OTP')],
          ),
        ),
      ),
    );

    expect(find.byType(Breadcrumbs), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(
      const WebPageHeader(
        title: 'x',
        crumbs: [Crumb('a')],
      ).preferredSize.height,
      WebTokens.pageHeaderWithCrumbsHeight,
    );
  });

  testWidgets('screens draw their own ☰ only on narrow native windows', (
    tester,
  ) async {
    // Default test surface is 800 px wide — a "medium" (non-wide) window.
    late bool showMenu;
    Widget probe() => MaterialApp(
      home: Builder(
        builder: (context) {
          showMenu = context.showScreenMenuButton;
          return const SizedBox.shrink();
        },
      ),
    );

    WebLayout.debugOverride = false;
    await tester.pumpWidget(probe());
    expect(showMenu, isTrue);

    WebLayout.debugOverride = true;
    await tester.pumpWidget(Container());
    await tester.pumpWidget(probe());
    expect(showMenu, isFalse, reason: 'the web shell top bar owns ☰');
  });
}
