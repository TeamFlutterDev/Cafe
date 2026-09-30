import 'package:cafe/core/widgets/app_data_table.dart';
import 'package:cafe/core/widgets/web_kit.dart';
import 'package:cafe/core/widgets/web_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => WebLayout.debugOverride = null);

  group('WebStatTile', () {
    testWidgets('shows value, label and a signed trend with an arrow icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const WebStatTile(
            label: 'Revenue',
            value: '₹12,400',
            icon: Icons.account_balance_wallet_rounded,
            trend: 12.5,
            caption: 'vs previous period',
          ),
        ),
      );

      expect(find.text('Revenue'), findsOneWidget);
      expect(find.text('₹12,400'), findsOneWidget);
      expect(find.text('+12.5%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.text('vs previous period'), findsOneWidget);
    });

    testWidgets('negative trend points down and has no plus sign', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const WebStatTile(
            label: 'Orders',
            value: '41',
            icon: Icons.shopping_bag_rounded,
            trend: -4.2,
          ),
        ),
      );

      expect(find.text('-4.2%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });
  });

  testWidgets('WebSegmented reports the tapped value and shows counts', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      _app(
        WebSegmented<String>(
          selected: 'ALL',
          onChanged: (v) => picked = v,
          segments: const [
            WebSegment('ALL', 'All', count: 9),
            WebSegment('CASH', 'Cash', count: 4),
          ],
        ),
      ),
    );

    expect(find.text('9'), findsOneWidget);
    await tester.tap(find.text('Cash'));
    expect(picked, 'CASH');
  });

  group('WebMasterDetail', () {
    Widget layout(double width, {bool withDetail = true}) => MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: _app(
        SizedBox(
          width: width,
          child: WebMasterDetail(
            master: const Text('LIST'),
            detail: withDetail
                ? const SizedBox(width: 400, child: Text('EDITOR'))
                : null,
          ),
        ),
      ),
    );

    testWidgets('docks the editor beside the list on wide windows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(layout(1500));
      expect(find.text('LIST'), findsOneWidget);
      expect(find.text('EDITOR'), findsOneWidget);
    });

    testWidgets('editor replaces the list when there is no room', (
      tester,
    ) async {
      await tester.pumpWidget(layout(800));
      expect(find.text('LIST'), findsNothing);
      expect(find.text('EDITOR'), findsOneWidget);
    });

    testWidgets('no detail = just the list', (tester) async {
      await tester.pumpWidget(layout(800, withDetail: false));
      expect(find.text('LIST'), findsOneWidget);
    });
  });

  testWidgets('WebSidePanel close button calls onClose', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            const Spacer(),
            WebSidePanel(
              title: 'Edit User',
              onClose: () => closed = true,
              child: const Text('form'),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Edit User'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    expect(closed, isTrue);
  });

  group('showAdaptiveEditor', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAdaptiveEditor<void>(
                  context: context,
                  builder: (_) => const Material(child: Text('EDITOR BODY')),
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

    testWidgets('web: opens a centred dialog', (tester) async {
      WebLayout.debugOverride = true;
      await open(tester);
      expect(find.text('EDITOR BODY'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('native: keeps the bottom sheet', (tester) async {
      WebLayout.debugOverride = false;
      await open(tester);
      expect(find.text('EDITOR BODY'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('AppDataTable on web', () {
    testWidgets('shows the record count and filters via search', (
      tester,
    ) async {
      WebLayout.debugOverride = true;
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: AppDataTable<String>(
              title: 'Tables',
              rows: const ['T1', 'T2', 'Garden 3'],
              searchText: (r) => r,
              columns: [AppColumn<String>(label: 'Name', value: (r) => r)],
            ),
          ),
        ),
      );

      expect(find.text('3 records'), findsOneWidget);
      expect(
        find.text('NAME'),
        findsOneWidget,
        reason: 'web headers are uppercase',
      );

      await tester.enterText(find.byType(TextField), 'garden');
      await tester.pump();
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('Garden 3'), findsOneWidget);
      expect(find.text('T1'), findsNothing);
    });

    testWidgets('empty search result shows a friendly empty state', (
      tester,
    ) async {
      WebLayout.debugOverride = true;
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: AppDataTable<String>(
              rows: const ['T1'],
              searchText: (r) => r,
              columns: [AppColumn<String>(label: 'Name', value: (r) => r)],
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No matches'), findsOneWidget);
    });
  });
}
