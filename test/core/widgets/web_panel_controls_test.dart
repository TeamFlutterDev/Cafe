import 'package:cafe/core/widgets/web_panel_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// A side panel that closes with [PanelCloseButton] and comes back with
/// [PanelReopenTab] — the same wiring the POS carts and web sidebar use.
class _ClosablePanel extends StatefulWidget {
  const _ClosablePanel();

  @override
  State<_ClosablePanel> createState() => _ClosablePanelState();
}

class _ClosablePanelState extends State<_ClosablePanel> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              const Expanded(child: Text('menu grid')),
              if (!_hidden)
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('Current Bill'),
                          const Spacer(),
                          PanelCloseButton(
                            tooltip: 'Close cart',
                            onPressed: () => setState(() => _hidden = true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_hidden)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: PanelReopenTab(
                  edge: PanelEdge.right,
                  icon: Icons.shopping_cart_rounded,
                  label: 'Cart',
                  count: 3,
                  onPressed: () => setState(() => _hidden = false),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('close hides the panel, the edge tab brings it back', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _ClosablePanel()));
    expect(find.text('Current Bill'), findsOneWidget);
    expect(find.byType(PanelReopenTab), findsNothing);

    await tester.tap(find.byTooltip('Close cart'));
    await tester.pump();
    expect(find.text('Current Bill'), findsNothing);
    expect(find.byType(PanelReopenTab), findsOneWidget);

    await tester.tap(find.byType(PanelReopenTab));
    await tester.pump();
    expect(find.text('Current Bill'), findsOneWidget);
    expect(find.byType(PanelReopenTab), findsNothing);
  });

  testWidgets('reopen tab shows the item count badge only when non-zero', (
    tester,
  ) async {
    Widget tab(int count) => MaterialApp(
      home: Scaffold(
        body: PanelReopenTab(
          edge: PanelEdge.left,
          icon: Icons.menu_rounded,
          label: 'Menu',
          count: count,
          onPressed: () {},
        ),
      ),
    );

    await tester.pumpWidget(tab(5));
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);

    await tester.pumpWidget(tab(0));
    expect(find.text('0'), findsNothing);
  });

  testWidgets('close button exposes its tooltip for mouse users', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PanelCloseButton(
            tooltip: 'Hide menu',
            onPressed: () => closed = true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Hide menu'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(closed, isTrue);
  });
}
