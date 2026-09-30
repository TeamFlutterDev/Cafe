import 'package:cafe/core/widgets/web_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late int toggles;
  late int logouts;
  late String? opened;

  setUp(() {
    toggles = 0;
    logouts = 0;
    opened = null;
  });

  Widget sidebar(double width) => MaterialApp(
    home: Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: width,
            child: WebSidebar(
              title: 'Rasabhojan',
              subtitle: 'Cafe Aroma',
              onToggle: () => toggles++,
              onLogout: () => logouts++,
              entries: [
                const WebSideSection('Navigation'),
                WebSideItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS Terminal',
                  selected: true,
                  onTap: () => opened = 'pos',
                ),
                const WebSideSection('Admin Masters'),
                WebSideItem(
                  icon: Icons.people_alt_rounded,
                  label: 'User Master',
                  onTap: () => opened = 'users',
                ),
              ],
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    ),
  );

  testWidgets('expanded: brand, section labels, item labels, logout text', (
    tester,
  ) async {
    await tester.pumpWidget(sidebar(WebSidebarSize.expanded));

    expect(find.text('Rasabhojan'), findsOneWidget);
    expect(find.text('Cafe Aroma'), findsOneWidget);
    expect(find.text('NAVIGATION'), findsOneWidget);
    expect(find.text('ADMIN MASTERS'), findsOneWidget);
    expect(find.text('User Master'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    await tester.tap(find.text('User Master'));
    expect(opened, 'users');
  });

  testWidgets('header button collapses the menu', (tester) async {
    await tester.pumpWidget(sidebar(WebSidebarSize.expanded));
    await tester.tap(find.byIcon(Icons.menu_open_rounded));
    expect(toggles, 1);
  });

  testWidgets('rail: icons only, labels moved to tooltips', (tester) async {
    await tester.pumpWidget(sidebar(WebSidebarSize.rail));

    expect(find.text('User Master'), findsNothing);
    expect(find.text('NAVIGATION'), findsNothing);
    expect(find.text('Logout'), findsNothing);
    expect(find.byTooltip('User Master'), findsOneWidget);
    expect(find.byTooltip('Logout'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.people_alt_rounded));
    expect(opened, 'users');

    await tester.tap(find.byIcon(Icons.logout_rounded));
    expect(logouts, 1);
  });

  testWidgets('rail: tapping the brand expands the menu again', (tester) async {
    await tester.pumpWidget(sidebar(WebSidebarSize.rail));
    await tester.tap(find.byIcon(Icons.restaurant_rounded));
    expect(toggles, 1);
  });

  testWidgets('edge toggle shows ‹ when expanded and › when collapsed', (
    tester,
  ) async {
    var pressed = 0;
    Widget edge(bool collapsed) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: WebSidebarEdgeToggle(
            collapsed: collapsed,
            onPressed: () => pressed++,
          ),
        ),
      ),
    );

    await tester.pumpWidget(edge(false));
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byTooltip('Collapse menu'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    expect(pressed, 1);

    await tester.pumpWidget(edge(true));
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byTooltip('Expand menu'), findsOneWidget);
  });
}
