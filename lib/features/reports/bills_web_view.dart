part of 'bills_screen.dart';

/// Desktop-web Bills & History: a reporting dashboard instead of the phone's
/// stacked tabs — date-range bar, KPI row, tabbed Overview / Insights /
/// Ledger, charts on a grid, and a full-width sortable bills ledger.
///
/// Pure presentation: every number is computed by [_BillsScreenState.build]
/// (the same figures the mobile view shows) and every action calls back into
/// the existing state methods.
class _BillsWebDashboard extends StatefulWidget {
  final ReportState state;
  final ReportNotifier notifier;
  final bool isDark;
  final Map<String, double> categorySales;
  final Map<String, int> itemQuantities;
  final Map<String, double> itemRevenues;
  final Map<int, double> hourlySales;
  final double totalTax;
  final double totalDiscount;
  final double aov;
  final String paymentInsight;
  final String hourlyInsight;
  final VoidCallback onExportPdf;
  final VoidCallback onCustomRange;
  final void Function(Bill bill) onOpenBill;

  const _BillsWebDashboard({
    required this.state,
    required this.notifier,
    required this.isDark,
    required this.categorySales,
    required this.itemQuantities,
    required this.itemRevenues,
    required this.hourlySales,
    required this.totalTax,
    required this.totalDiscount,
    required this.aov,
    required this.paymentInsight,
    required this.hourlyInsight,
    required this.onExportPdf,
    required this.onCustomRange,
    required this.onOpenBill,
  });

  @override
  State<_BillsWebDashboard> createState() => _BillsWebDashboardState();
}

class _BillsWebDashboardState extends State<_BillsWebDashboard> {
  int _tab = 0;
  String _payment = 'ALL';

  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _rowDateFmt = DateFormat('d MMM, hh:mm a');

  ReportState get _s => widget.state;
  bool get _dark => widget.isDark;

  String _money(double v, {int decimals = 0}) =>
      '₹${NumberFormat.decimalPattern('en_IN').format(double.parse(v.toStringAsFixed(decimals)))}';

  String get _rangeLabel {
    final s = _s.startDate, e = _s.endDate;
    if (s != null && e != null) {
      final a = _dateFmt.format(s), b = _dateFmt.format(e);
      return a == b ? a : '$a – $b';
    }
    return 'Today';
  }

  double? _trend(double now, double before) =>
      before > 0 ? ((now - before) / before) * 100 : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WebPalette.canvas(_dark),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (_s.isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              color: WebPalette.accent(_dark),
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: WebPageBody(
              onRefresh: () => widget.notifier.fetchReport(),
              children: [
                if (!_s.isLoading && _s.error != null) ...[
                  _errorBanner(_s.error!),
                  const SizedBox(height: WebSpace.lg),
                ],
                _kpis(),
                const SizedBox(height: WebSpace.xl),
                _tabs(),
                const SizedBox(height: WebSpace.lg),
                ...switch (_tab) {
                  0 => _overview(),
                  1 => _insights(),
                  _ => _ledger(),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header: title, range, date filter, actions ───

  Widget _header() {
    final f = _s.filter;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        WebTokens.gutter,
        WebSpace.lg,
        WebTokens.gutter,
        WebSpace.lg,
      ),
      decoration: BoxDecoration(
        color: WebPalette.surface(_dark),
        border: Border(bottom: BorderSide(color: WebPalette.border(_dark))),
      ),
      child: Wrap(
        spacing: WebSpace.lg,
        runSpacing: WebSpace.md,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WebIconBadge(
                icon: Icons.receipt_long_rounded,
                color: WebPalette.accent(_dark),
                size: 44,
              ),
              const SizedBox(width: WebSpace.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bills & History',
                    style: GoogleFonts.inter(
                      fontSize: WebTokens.pageTitleFontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: WebPalette.text(_dark),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 14,
                        color: WebPalette.muted(_dark),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _rangeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: WebPalette.muted(_dark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: WebSegmented<ReportDateFilter>(
                  selected: f,
                  onChanged: (v) {
                    if (v == ReportDateFilter.custom) {
                      widget.onCustomRange();
                    } else {
                      widget.notifier.setFilter(v);
                    }
                  },
                  segments: const [
                    WebSegment(ReportDateFilter.today, 'Today'),
                    WebSegment(ReportDateFilter.thisWeek, 'This week'),
                    WebSegment(ReportDateFilter.thisMonth, 'This month'),
                    WebSegment(ReportDateFilter.weekComparison, 'Week vs week'),
                    WebSegment(ReportDateFilter.yearComparison, 'Year vs year'),
                    WebSegment(
                      ReportDateFilter.custom,
                      'Custom',
                      icon: Icons.date_range_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WebSpace.md),
              OutlinedButton.icon(
                onPressed: widget.onExportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Export PDF'),
              ),
              const SizedBox(width: WebSpace.xs),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => widget.notifier.fetchReport(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: WebSpace.lg,
        vertical: WebSpace.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WebSpace.radiusSm),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: WebSpace.md),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: () => widget.notifier.fetchReport(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ─── KPI row ───

  Widget _kpis() {
    final prevRevenue = _s.comparisonBills.fold<double>(
      0,
      (a, b) => a + b.totalAmount,
    );
    final prevOrders = _s.comparisonBills.length.toDouble();
    final revenue = _s.totalRevenue;
    final digital = _s.upiTotal + _s.cardTotal;

    return WebResponsiveRow(
      minChildWidth: 200,
      children: [
        WebStatTile(
          label: 'Revenue',
          value: _money(revenue),
          icon: Icons.account_balance_wallet_rounded,
          trend: _s.comparisonBills.isEmpty
              ? null
              : _trend(revenue, prevRevenue),
          caption: _s.comparisonBills.isEmpty
              ? 'Net of cancellations'
              : 'vs previous period',
        ),
        WebStatTile(
          label: 'Orders',
          value: '${_s.totalOrders}',
          icon: Icons.shopping_bag_rounded,
          accent: AppColors.info,
          trend: _s.comparisonBills.isEmpty
              ? null
              : _trend(_s.totalOrders.toDouble(), prevOrders),
          caption: _s.comparisonBills.isEmpty
              ? 'Settled bills'
              : 'vs previous period',
        ),
        WebStatTile(
          label: 'Avg. ticket',
          value: _money(widget.aov),
          icon: Icons.local_offer_rounded,
          accent: AppColors.accentTeal,
          caption: 'Revenue ÷ orders',
        ),
        WebStatTile(
          label: 'Cash',
          value: _money(_s.cashTotal),
          icon: Icons.payments_rounded,
          accent: AppColors.tableFree,
          progress: revenue > 0 ? _s.cashTotal / revenue : 0,
          caption: revenue > 0
              ? '${(_s.cashTotal / revenue * 100).toStringAsFixed(0)}% of revenue'
              : 'No sales yet',
        ),
        WebStatTile(
          label: 'UPI & card',
          value: _money(digital),
          icon: Icons.qr_code_2_rounded,
          accent: const Color(0xFF6D28D9),
          progress: revenue > 0 ? digital / revenue : 0,
          caption: revenue > 0
              ? '${(digital / revenue * 100).toStringAsFixed(0)}% of revenue'
              : 'No sales yet',
        ),
        WebStatTile(
          label: 'Tax collected',
          value: _money(widget.totalTax),
          icon: Icons.account_balance_rounded,
          accent: AppColors.warning,
          caption: 'Discounts ${_money(widget.totalDiscount)}',
        ),
      ],
    );
  }

  // ─── Tabs ───

  Widget _tabs() {
    return Align(
      alignment: Alignment.centerLeft,
      child: WebSegmented<int>(
        selected: _tab,
        onChanged: (i) => setState(() => _tab = i),
        segments: [
          const WebSegment(0, 'Overview', icon: Icons.dashboard_rounded),
          const WebSegment(1, 'Sales insights', icon: Icons.insights_rounded),
          WebSegment(
            2,
            'Bills ledger',
            icon: Icons.list_alt_rounded,
            count: _s.bills.length,
          ),
        ],
      ),
    );
  }

  Widget _insight(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(WebSpace.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _dark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(WebSpace.radius),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: WebSpace.md),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: WebPalette.text(_dark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _trendTitle => switch (_s.filter) {
    ReportDateFilter.thisWeek => 'Payment mode trend',
    ReportDateFilter.weekComparison => 'Week-over-week sales',
    ReportDateFilter.yearComparison => 'Year-over-year sales',
    _ => 'Sales analysis',
  };

  List<Widget> _overview() => [
    WebResponsiveRow(
      minChildWidth: 360,
      children: [
        _insight(
          widget.paymentInsight,
          Icons.lightbulb_outline_rounded,
          AppColors.primaryAmber,
        ),
        _insight(
          widget.hourlyInsight,
          Icons.schedule_rounded,
          AppColors.accentTeal,
        ),
      ],
    ),
    const SizedBox(height: WebSpace.lg),
    LayoutBuilder(
      builder: (context, c) {
        final trend = WebCard(
          title: _trendTitle,
          subtitle: _rangeLabel,
          icon: Icons.show_chart_rounded,
          height: 380,
          child: AnalysisChart(state: _s, isDark: _dark),
        );
        final split = WebCard(
          title: 'Payment modes',
          subtitle: 'Share of revenue',
          icon: Icons.donut_large_rounded,
          height: 380,
          child: PaymentSplitChart(
            cash: _s.cashTotal,
            upi: _s.upiTotal,
            card: _s.cardTotal,
            isDark: _dark,
          ),
        );
        if (c.maxWidth < 980) {
          return Column(
            children: [
              trend,
              const SizedBox(height: WebSpace.lg),
              split,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: trend),
            const SizedBox(width: WebSpace.lg),
            Expanded(child: split),
          ],
        );
      },
    ),
    const SizedBox(height: WebSpace.lg),
    WebResponsiveRow(
      minChildWidth: 420,
      children: [
        WebCard(
          title: 'Busy hours',
          subtitle: 'Revenue by hour of day',
          icon: Icons.schedule_rounded,
          height: 320,
          child: HourlySalesChart(
            hourlySales: widget.hourlySales,
            isDark: _dark,
          ),
        ),
        WebCard(
          title: 'Table-wise sales',
          subtitle: 'Revenue per table',
          icon: Icons.table_restaurant_rounded,
          height: 320,
          child: TableSalesChart(tableSales: _s.tableSales, isDark: _dark),
        ),
      ],
    ),
  ];

  List<Widget> _insights() => [
    WebResponsiveRow(
      minChildWidth: 420,
      children: [
        WebCard(
          title: 'Sales by category',
          subtitle: 'Where revenue comes from',
          icon: Icons.pie_chart_outline_rounded,
          height: 360,
          child: CategoryPieChart(
            categorySales: widget.categorySales,
            isDark: _dark,
          ),
        ),
        WebCard(
          title: 'Top selling items',
          subtitle: 'By quantity sold',
          icon: Icons.local_fire_department_rounded,
          height: 360,
          child: SingleChildScrollView(
            child: TopSellingItemsList(
              itemQuantities: widget.itemQuantities,
              itemRevenues: widget.itemRevenues,
              isDark: _dark,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: WebSpace.lg),
    WebResponsiveRow(
      minChildWidth: 420,
      children: [
        WebCard(
          title: 'Cover-wise sales',
          subtitle: 'Revenue per cover / guest group',
          icon: Icons.groups_rounded,
          height: 360,
          child: SingleChildScrollView(
            child: CoverSalesWidget(
              coverEntries: _s.coverEntries,
              totalRevenue: _s.totalRevenue,
              isDark: _dark,
            ),
          ),
        ),
        WebCard(
          title: 'Tax & audit summary',
          subtitle: 'For the selected period',
          icon: Icons.fact_check_rounded,
          height: 360,
          child: Column(
            children: [
              _auditRow('Gross revenue', _money(_s.totalRevenue, decimals: 2)),
              _auditRow(
                'Subtotal before tax',
                _money(_s.totalGrossAmount, decimals: 2),
              ),
              _auditRow(
                'Tax collected (CGST + SGST)',
                _money(widget.totalTax, decimals: 2),
              ),
              _auditRow(
                'Discounts given',
                '− ${_money(widget.totalDiscount, decimals: 2)}',
                negative: true,
              ),
              _auditRow('Average order value', _money(widget.aov, decimals: 2)),
              _auditRow('Orders', '${_s.totalOrders}', last: true),
            ],
          ),
        ),
      ],
    ),
  ];

  Widget _auditRow(
    String label,
    String value, {
    bool negative = false,
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: WebSpace.md),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: WebPalette.border(_dark))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: WebPalette.muted(_dark),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: negative ? AppColors.error : WebPalette.text(_dark),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Ledger ───

  List<Widget> _ledger() {
    final bills = _payment == 'ALL'
        ? _s.bills
        : _s.bills
              .where((b) => b.paymentMode.toUpperCase() == _payment)
              .toList();
    int count(String mode) =>
        _s.bills.where((b) => b.paymentMode.toUpperCase() == mode).length;

    return [
      AppDataTable<Bill>(
        title: 'Bills',
        rows: bills,
        rowsPerPage: 25,
        emptyMessage: 'No bills in this period',
        searchText: (b) =>
            '${b.billNumber ?? ''} ${b.tableName ?? ''} ${b.coverDisplayName} ${b.paymentMode} ${b.status}',
        onRowTap: widget.onOpenBill,
        toolbar: [
          WebSegmented<String>(
            selected: _payment,
            onChanged: (v) => setState(() => _payment = v),
            segments: [
              WebSegment('ALL', 'All', count: _s.bills.length),
              WebSegment('CASH', 'Cash', count: count('CASH')),
              WebSegment('UPI', 'UPI', count: count('UPI')),
              WebSegment('CARD', 'Card', count: count('CARD')),
            ],
          ),
        ],
        actions: [
          AppRowAction<Bill>(
            'View details',
            Icons.visibility_outlined,
            widget.onOpenBill,
          ),
        ],
        columns: [
          AppColumn<Bill>(
            label: 'Bill #',
            value: (b) => b.billNumber ?? b.id,
            cell: (b) => Text(
              b.billNumber ?? b.id.substring(0, 8),
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
          AppColumn<Bill>(
            label: 'Date & time',
            value: (b) => b.createdAt ?? DateTime(0),
            size: ColumnSize.L,
            cell: (b) => Text(
              b.createdAt != null
                  ? _rowDateFmt.format(b.createdAt!.toLocal())
                  : '—',
              style: GoogleFonts.inter(color: WebPalette.muted(_dark)),
            ),
          ),
          AppColumn<Bill>(
            label: 'Table',
            value: (b) => b.tableName ?? '',
            minWindow: WindowClass.expanded,
            cell: (b) => Text(
              b.tableName == null
                  ? 'Takeaway'
                  : (b.coverNumber != null
                        ? '${b.tableName} · ${b.coverDisplayName}'
                        : b.tableName!),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppColumn<Bill>(
            label: 'Items',
            value: (b) => b.items.length,
            numeric: true,
            size: ColumnSize.S,
            minWindow: WindowClass.large,
          ),
          AppColumn<Bill>(
            label: 'Payment',
            value: (b) => b.paymentMode,
            size: ColumnSize.S,
            cell: (b) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  switch (b.paymentMode.toUpperCase()) {
                    'CASH' => Icons.payments_outlined,
                    'UPI' => Icons.qr_code_2_rounded,
                    _ => Icons.credit_card_rounded,
                  },
                  size: 16,
                  color: WebPalette.muted(_dark),
                ),
                const SizedBox(width: 6),
                Text(b.paymentMode.toUpperCase()),
              ],
            ),
          ),
          AppColumn<Bill>(
            label: 'Amount',
            value: (b) => b.totalAmount,
            numeric: true,
            cell: (b) => Text(
              _money(b.totalAmount, decimals: 2),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                decoration: b.isCancelled ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          AppColumn<Bill>(
            label: 'Status',
            value: (b) => b.isCancelled ? 'CANCELLED' : b.status,
            size: ColumnSize.S,
            cell: (b) => b.isCancelled
                ? const WebStatusPill(
                    label: 'Cancelled',
                    color: AppColors.error,
                    icon: Icons.block_rounded,
                  )
                : const WebStatusPill(
                    label: 'Paid',
                    color: AppColors.tableFree,
                    icon: Icons.check_rounded,
                  ),
          ),
        ],
      ),
    ];
  }
}
