import 'package:cafe/core/widgets/breadcrumbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Test harness mirroring the web shell: a trail bar above a nested
/// navigator observed by [controller].
class _Harness extends StatelessWidget {
  final BreadcrumbController controller;
  final GlobalKey<NavigatorState> navKey;
  final Widget root;

  const _Harness({
    required this.controller,
    required this.navKey,
    required this.root,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: 40,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Breadcrumbs(
                  crumbs: controller.trail(
                    leading: const [Crumb('Home', icon: Icons.home_rounded)],
                  ),
                ),
              ),
            ),
            Expanded(
              child: BreadcrumbScope(
                controller: controller,
                child: Navigator(
                  key: navKey,
                  observers: [controller],
                  pages: [MaterialPage<void>(name: 'Item Group', child: root)],
                  onDidRemovePage: (_) {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crumb labels as rendered inside the trail, in order.
List<String> _renderedTrail(WidgetTester tester) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byType(Breadcrumbs), matching: find.byType(Text)),
  );
  return [for (final t in texts) t.data ?? ''];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Breadcrumbs widget', () {
    testWidgets('renders every crumb with separators between them', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Breadcrumbs(
              crumbs: [Crumb('Home'), Crumb('Admin Masters'), Crumb('Users')],
            ),
          ),
        ),
      );

      expect(_renderedTrail(tester), ['Home', 'Admin Masters', 'Users']);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
    });

    testWidgets('earlier crumbs are tappable, the current one is not', (
      tester,
    ) async {
      var homeTaps = 0;
      var currentTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Breadcrumbs(
              crumbs: [
                Crumb('Home', onTap: () => homeTaps++),
                Crumb('Users', onTap: () => currentTaps++),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Home'));
      await tester.tap(find.text('Users'), warnIfMissed: false);

      expect(homeTaps, 1);
      expect(currentTaps, 0, reason: 'the current page is never a link');
    });

    testWidgets('empty trail renders nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Breadcrumbs(crumbs: [])),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });
  });

  group('BreadcrumbController', () {
    late BreadcrumbController controller;
    late GlobalKey<NavigatorState> navKey;

    setUp(() {
      controller = BreadcrumbController();
      navKey = GlobalKey<NavigatorState>();
    });

    tearDown(() => controller.dispose());

    testWidgets('trail follows the navigator stack using route names', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          controller: controller,
          navKey: navKey,
          root: const Text('root page'),
        ),
      );
      await tester.pump();
      expect(_renderedTrail(tester), ['Home', 'Item Group']);

      navKey.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'Burger'),
          builder: (_) => const Text('variants page'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_renderedTrail(tester), ['Home', 'Item Group', 'Burger']);

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_renderedTrail(tester), ['Home', 'Item Group']);
    });

    testWidgets('tapping an earlier crumb pops back to that page', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          controller: controller,
          navKey: navKey,
          root: const Text('root page'),
        ),
      );
      final nav = navKey.currentState!;
      nav.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'Burger'),
          builder: (_) => const Text('variants page'),
        ),
      );
      await tester.pumpAndSettle();
      nav.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'Recipe'),
          builder: (_) => const Text('recipe page'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_renderedTrail(tester), [
        'Home',
        'Item Group',
        'Burger',
        'Recipe',
      ]);

      await tester.tap(find.text('Item Group'));
      await tester.pumpAndSettle();

      expect(find.text('root page'), findsOneWidget);
      expect(find.text('recipe page'), findsNothing);
      expect(_renderedTrail(tester), ['Home', 'Item Group']);
    });

    testWidgets('dialogs and sheets never become crumbs', (tester) async {
      await tester.pumpWidget(
        _Harness(
          controller: controller,
          navKey: navKey,
          root: const Text('root page'),
        ),
      );
      showDialog<void>(
        context: navKey.currentContext!,
        useRootNavigator: false,
        builder: (_) => const AlertDialog(title: Text('Confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      expect(_renderedTrail(tester), ['Home', 'Item Group']);
    });

    testWidgets('unnamed routes fall back to "Details"', (tester) async {
      await tester.pumpWidget(
        _Harness(
          controller: controller,
          navKey: navKey,
          root: const Text('root page'),
        ),
      );
      navKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('unnamed')),
      );
      await tester.pumpAndSettle();
      expect(_renderedTrail(tester).last, 'Details');
    });
  });

  group('BreadcrumbTail', () {
    testWidgets('adds in-page crumbs and makes the page crumb run onBaseTap', (
      tester,
    ) async {
      final controller = BreadcrumbController();
      addTearDown(controller.dispose);
      final navKey = GlobalKey<NavigatorState>();
      final editing = ValueNotifier<bool>(true);
      addTearDown(editing.dispose);

      await tester.pumpWidget(
        _Harness(
          controller: controller,
          navKey: navKey,
          root: ValueListenableBuilder<bool>(
            valueListenable: editing,
            builder: (_, isEditing, _) => BreadcrumbTail(
              crumbs: isEditing ? const [Crumb('Edit Item Group')] : const [],
              onBaseTap: isEditing ? () => editing.value = false : null,
              child: Text(isEditing ? 'editor' : 'list'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_renderedTrail(tester), ['Home', 'Item Group', 'Edit Item Group']);

      await tester.tap(find.text('Item Group'));
      await tester.pump();
      await tester.pump();

      expect(editing.value, isFalse);
      expect(find.text('list'), findsOneWidget);
      expect(_renderedTrail(tester), ['Home', 'Item Group']);
    });

    testWidgets('is a transparent wrapper without a BreadcrumbScope', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BreadcrumbTail(crumbs: [Crumb('Edit')], child: Text('page')),
        ),
      );
      expect(find.text('page'), findsOneWidget);
      expect(find.byType(Breadcrumbs), findsNothing);
    });
  });
}
