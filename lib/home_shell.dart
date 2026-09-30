import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'core/widgets/breadcrumbs.dart';
import 'core/widgets/web_layout.dart';
import 'core/widgets/web_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/widgets/window_class.dart';
import 'models/models.dart';
import 'providers/providers.dart';
import 'features/pos/presentation/modern_pos_screen.dart';
import 'features/pos/presentation/quick_bill_screen.dart';
import 'features/pos/presentation/classic_pos_screen.dart';
import 'features/orders/tables_screen.dart';
import 'features/reports/bills_screen.dart';
import 'features/admin/presentation/company_master_screen.dart';
import 'features/admin/presentation/user_master_screen.dart';
import 'features/admin/presentation/item_master_screen.dart';
import 'features/admin/presentation/item_variant_screen.dart';
import 'features/admin/presentation/table_master_screen.dart';
import 'features/kitchen/kitchen_screen.dart';
import 'features/admin/presentation/my_profile_screen.dart';
import 'features/admin/presentation/stock/stock_dashboard_screen.dart';

/// The signed-in app shell (POS/Tables/Bills + admin nav) — rendered by the
/// `/` route once `AppRouter`'s redirect confirms a non-owner, authenticated
/// user. Login/owner-dashboard routing now lives in
/// `core/routing/app_router.dart`, not here.
///
/// Two presentations:
/// * **Native** — drawer (or permanent panel on wide tablets); the modules
///   swap in the body and every other page is `Navigator.push`ed full-screen
///   with its own AppBar back button. Unchanged from before.
/// * **Web** ([WebLayout.enabled]) — a flat sidebar, a top bar with the
///   breadcrumb trail, and a nested content [Navigator]: every destination
///   (modules *and* admin pages) opens inside it, so the sidebar never
///   disappears, and anything a page pushes from there (e.g. Item Group →
///   Variants) lands in it too and shows up in the breadcrumbs.
class AuthenticatedShell extends ConsumerStatefulWidget {
  final UserProfile user;
  const AuthenticatedShell({super.key, required this.user});

  @override
  ConsumerState<AuthenticatedShell> createState() =>
      AuthenticatedShellState();
}

class AuthenticatedShellState extends ConsumerState<AuthenticatedShell>
    with WidgetsBindingObserver {
  int _selectedNavIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ─── Web shell state ───
  final GlobalKey<NavigatorState> _webNavKey = GlobalKey<NavigatorState>();
  final BreadcrumbController _crumbs = BreadcrumbController();

  /// The destination open in the web content navigator (`_NavPage.id`, or a
  /// module's id). Null = the first module.
  String? _webDestId;

  /// Id of the destination the last web build actually showed (resolves the
  /// null / fallen-back cases of [_webDestId]).
  String? _openWebId;

  /// Web, wide windows: sidebar collapsed to an icon rail. Toggled by the
  /// header button / edge ‹ › button; remembered across sessions.
  bool _sidebarCollapsed = false;
  static const _sidebarPrefKey = 'web_sidebar_collapsed';

  // Periodically re-validates the session against the server so a deactivated /
  // force-logged-out / another-device login kicks this device to login quickly.
  Timer? _sessionTimer;
  static const _sessionCheckInterval = Duration(seconds: 20);

  bool get _isWaiter => widget.user.isWaiter;
  bool get _isKitchen => widget.user.isKitchen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (WebLayout.enabled) _restoreSidebarState();
    // Check once right away, then on an interval.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).validateSession();
    });
    _sessionTimer = Timer.periodic(
      _sessionCheckInterval,
      (_) => ref.read(authStateProvider.notifier).validateSession(),
    );
  }

  Future<void> _restoreSidebarState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final collapsed = prefs.getBool(_sidebarPrefKey) ?? false;
      if (mounted && collapsed != _sidebarCollapsed) {
        setState(() => _sidebarCollapsed = collapsed);
      }
    } catch (_) {
      // Storage blocked (private mode etc.) — just start expanded.
    }
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_sidebarPrefKey, _sidebarCollapsed))
        .catchError((Object _) => true);
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _crumbs.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check the moment the app returns to the foreground.
    if (state == AppLifecycleState.resumed) {
      ref.read(authStateProvider.notifier).validateSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTheme = ref.watch(selectedUiThemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = widget.user;

    // Effective module access. Admins bypass gating; otherwise use the cached
    // permission set, falling back to role defaults for legacy sessions that
    // were created before permissions were cached.
    final perms =
        ref.watch(permissionsProvider) ??
        (user.isAdmin
            ? UserPermission.all(user.id)
            : UserPermission.forRole(user.id, user.role));

    final isWide = context.isWideWindow;
    final pages = _pagesFor(perms);

    // Kitchen role: dedicated full-screen KOT display.
    if (_isKitchen) {
      if (WebLayout.enabled) {
        return _buildWebShell(
          context,
          isDark,
          [
            _NavModule(
              Icons.restaurant_rounded,
              'Kitchen Display',
              KitchenScreen(companyId: user.companyId),
            ),
          ],
          pages,
        );
      }
      return Scaffold(
        key: _scaffoldKey,
        drawer: isWide
            ? null
            : _buildNavPanel(context, isDark, const [], pages, isPermanent: false),
        body: isWide
            ? Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: _buildNavPanel(context, isDark, const [], pages, isPermanent: true),
                  ),
                  Expanded(child: KitchenScreen(companyId: user.companyId)),
                ],
              )
            : KitchenScreen(companyId: user.companyId),
      );
    }

    // Build the navigable modules from the user's access. Waiters keep their
    // dedicated tables-only flow.
    final List<_NavModule> modules;
    if (_isWaiter) {
      modules = [
        _NavModule(
          Icons.table_restaurant_rounded,
          'Tables & KOT',
          TablesScreen(companyId: user.companyId),
        ),
      ];
    } else {
      Widget posScreen;
      switch (selectedTheme) {
        case AppConstants.uiQuickBill:
          posScreen = const QuickBillScreen();
          break;
        case AppConstants.uiClassic:
          posScreen = const ClassicPosScreen();
          break;
        case AppConstants.uiModern:
        default:
          posScreen = const ModernPosScreen();
      }
      modules = [
        if (perms.canCreateBill)
          _NavModule(Icons.point_of_sale_rounded, 'POS Terminal', posScreen),
        if (perms.canManageTables)
          _NavModule(
            Icons.table_restaurant_rounded,
            'Tables & KOT',
            TablesScreen(companyId: user.companyId),
          ),
        if (perms.canViewReports)
          _NavModule(
            Icons.receipt_long_rounded,
            'Bills & History',
            BillsScreen(companyId: user.companyId),
          ),
      ];
      // Never leave the shell empty — fall back to POS if nothing was granted.
      if (modules.isEmpty) {
        modules.add(
          _NavModule(Icons.point_of_sale_rounded, 'POS Terminal', posScreen),
        );
      }
    }

    if (WebLayout.enabled) {
      return _buildWebShell(context, isDark, modules, pages);
    }

    final safeIndex = _selectedNavIndex.clamp(0, modules.length - 1);

    return Scaffold(
      key: _scaffoldKey,
      drawer: isWide
          ? null
          : _buildNavPanel(context, isDark, modules, pages, isPermanent: false),
      body: isWide
          ? Row(
              children: [
                SizedBox(
                  width: 300,
                  child: _buildNavPanel(context, isDark, modules, pages, isPermanent: true),
                ),
                Expanded(child: modules[safeIndex].screen),
              ],
            )
          : modules[safeIndex].screen,
    );
  }

  // ─── Destinations ────────────────────────────────────────────────────────

  static const _sectionAdmin = 'Admin Masters';
  static const _sectionAccount = 'Account';

  /// Every non-module destination the nav offers these permissions, in nav
  /// order. Gating mirrors the old hand-written drawer exactly: the kitchen
  /// role only ever gets My Profile.
  List<_NavPage> _pagesFor(UserPermission perms) {
    final profile = _NavPage(
      id: 'profile',
      icon: Icons.person_outline_rounded,
      label: 'My Profile',
      section: _sectionAccount,
      closeFirst: true,
      builder: () => MyProfileScreen(user: widget.user),
    );
    if (_isKitchen) return [profile];

    return [
      if (perms.canManageTables)
        _NavPage(
          id: 'kitchen',
          icon: Icons.soup_kitchen_rounded,
          label: 'Kitchen Monitor',
          closeFirst: true,
          builder: () => KitchenScreen(companyId: widget.user.companyId),
        ),
      if (perms.canManageSettings)
        _NavPage(
          id: 'company',
          icon: Icons.business_rounded,
          label: 'Company Master',
          section: _sectionAdmin,
          builder: () => const CompanyMasterScreen(),
        ),
      if (perms.canManageTables)
        _NavPage(
          id: 'tables-master',
          icon: Icons.table_restaurant_rounded,
          label: 'Table Master',
          section: _sectionAdmin,
          builder: () => const TableMasterScreen(),
        ),
      if (perms.canManageUsers)
        _NavPage(
          id: 'users',
          icon: Icons.people_alt_rounded,
          label: 'User Master',
          section: _sectionAdmin,
          builder: () => const UserMasterScreen(),
        ),
      if (perms.canManageItems)
        _NavPage(
          id: 'item-groups',
          icon: Icons.category_rounded,
          label: 'Item Group',
          section: _sectionAdmin,
          builder: () => const ItemMasterScreen(),
        ),
      if (perms.canManageItems)
        _NavPage(
          id: 'item-variants',
          icon: Icons.inventory_2_rounded,
          label: 'Item Variant',
          section: _sectionAdmin,
          builder: () => const ItemVariantScreen(),
        ),
      if (perms.canManageStock)
        _NavPage(
          id: 'stock',
          icon: Icons.warehouse_rounded,
          label: 'Stock & Inventory',
          section: _sectionAdmin,
          closeFirst: true,
          builder: () => const StockSectionScreen(),
        ),
      profile,
    ];
  }

  // ─── Web shell ───────────────────────────────────────────────────────────

  _NavPage _currentWebDest(List<_NavModule> modules, List<_NavPage> pages) {
    final all = [for (final m in modules) m.asPage, ...pages];
    return all.firstWhere(
      (d) => d.id == _webDestId,
      // A destination that disappeared (permissions changed) falls back home.
      orElse: () => all.first,
    );
  }

  /// Opens [dest] in the web content navigator. Re-selecting the open
  /// destination returns to its root page (drops anything pushed on top).
  void _selectWebDest(_NavPage dest, {required bool isPermanent}) {
    if (!isPermanent) _scaffoldKey.currentState?.closeDrawer();
    if (dest.id == _openWebId) {
      _webNavKey.currentState?.popUntil((r) => r.isFirst);
    }
    setState(() => _webDestId = dest.id);
  }

  Widget _buildWebShell(
    BuildContext context,
    bool isDark,
    List<_NavModule> modules,
    List<_NavPage> pages,
  ) {
    final isWide = context.isWideWindow;
    final current = _currentWebDest(modules, pages);
    _openWebId = current.id;
    final home = modules.first.asPage;

    final leading = <Crumb>[
      Crumb(
        'Home',
        icon: Icons.home_rounded,
        onTap: () => _selectWebDest(home, isPermanent: true),
      ),
      if (current.section != null) Crumb(current.section!),
    ];

    final sidebarWidth = _sidebarCollapsed
        ? WebSidebarSize.rail
        : WebSidebarSize.expanded;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      drawer: isWide
          ? null
          : Drawer(
              width: WebSidebarSize.expanded + 16,
              shape: const RoundedRectangleBorder(),
              child: _buildWebSidebar(
                isDark,
                modules,
                pages,
                current.id,
                inDrawer: true,
              ),
            ),
      body: Stack(
        children: [
          Row(
        children: [
          if (isWide)
            AnimatedContainer(
              duration: WebSidebarSize.animation,
              curve: Curves.easeOutCubic,
              width: sidebarWidth,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: _buildWebSidebar(
                isDark,
                modules,
                pages,
                current.id,
                inDrawer: false,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                _buildWebTopBar(isDark, isWide, leading, pages),
                Expanded(
                  child: BreadcrumbScope(
                    controller: _crumbs,
                    child: ClipRect(
                      child: Navigator(
                        key: _webNavKey,
                        observers: [_crumbs],
                        pages: [
                          MaterialPage<void>(
                            key: ValueKey(current.id),
                            name: current.label,
                            child: current.builder(),
                          ),
                        ],
                        onDidRemovePage: (_) {},
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
          // ‹ / › on the sidebar's right border.
          if (isWide)
            AnimatedPositioned(
              duration: WebSidebarSize.animation,
              curve: Curves.easeOutCubic,
              left: sidebarWidth - 13,
              top: 0,
              bottom: 0,
              child: Center(
                child: WebSidebarEdgeToggle(
                  collapsed: _sidebarCollapsed,
                  onPressed: _toggleSidebar,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Web side menu (permanent on wide windows, slide-out [Drawer] on narrow
  /// ones). Same destinations and gating as the native nav panel.
  Widget _buildWebSidebar(
    bool isDark,
    List<_NavModule> modules,
    List<_NavPage> pages,
    String currentId, {
    required bool inDrawer,
  }) {
    WebSideItem item(_NavPage page) => WebSideItem(
      icon: page.icon,
      label: page.label,
      selected: currentId == page.id,
      onTap: () => _selectWebDest(page, isPermanent: !inDrawer),
    );

    final entries = <WebSideEntry>[
      WebSideSection(_isKitchen ? 'Kitchen' : 'Navigation'),
      for (final m in modules) item(m.asPage),
      for (final p in pages.where((p) => p.section == null)) item(p),
      if (pages.any((p) => p.section == _sectionAdmin)) ...[
        const WebSideSection(_sectionAdmin),
        for (final p in pages.where((p) => p.section == _sectionAdmin)) item(p),
      ],
      if (pages.any((p) => p.section == _sectionAccount)) ...[
        const WebSideSection(_sectionAccount),
        for (final p in pages.where((p) => p.section == _sectionAccount)) item(p),
      ],
    ];

    final company = ref.watch(companyProvider(widget.user.companyId)).value;

    return WebSidebar(
      title: 'Rasabhojan',
      subtitle: company?.companyName ?? 'POS Console',
      entries: entries,
      onLogout: () => ref.read(authStateProvider.notifier).signOut(),
      toggleIcon: inDrawer ? Icons.close_rounded : Icons.menu_open_rounded,
      toggleTooltip: inDrawer
          ? 'Close menu'
          : (_sidebarCollapsed ? 'Expand menu' : 'Collapse menu'),
      onToggle: inDrawer
          ? () => _scaffoldKey.currentState?.closeDrawer()
          : _toggleSidebar,
    );
  }

  Widget _buildWebTopBar(
    bool isDark,
    bool isWide,
    List<Crumb> leading,
    List<_NavPage> pages,
  ) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fg = isDark ? AppColors.textWhite : AppColors.textDark;

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Container(
        height: WebTokens.topBarHeight,
        padding: EdgeInsets.only(
          left: isWide ? WebTokens.gutter : WebTokens.gap,
          right: WebTokens.gap * 2,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            // Narrow windows: opens the slide-out menu. (Wide windows
            // collapse/expand the sidebar from the sidebar itself.)
            if (!isWide)
              IconButton(
                icon: Icon(Icons.menu_rounded, color: fg),
                tooltip: 'Menu',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ListenableBuilder(
                  listenable: _crumbs,
                  builder: (context, _) =>
                      Breadcrumbs(crumbs: _crumbs.trail(leading: leading)),
                ),
              ),
            ),
            IconButton(
              tooltip: isDark ? 'Light mode' : 'Dark mode',
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: fg,
              ),
              onPressed: () => ref.read(isDarkModeProvider.notifier).toggle(),
            ),
            const SizedBox(width: WebTokens.gap / 2),
            _buildWebUserMenu(isDark, isWide, pages),
          ],
        ),
      ),
    );
  }

  Widget _buildWebUserMenu(bool isDark, bool isWide, List<_NavPage> pages) {
    final user = widget.user;
    final profile = pages.where((p) => p.id == 'profile').firstOrNull;
    final initials = user.fullName.isNotEmpty
        ? user.fullName
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0] : '')
              .join()
              .toUpperCase()
        : '?';

    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 'profile' && profile != null) {
          _selectWebDest(profile, isPermanent: true);
        } else if (value == 'logout') {
          ref.read(authStateProvider.notifier).signOut();
        }
      },
      itemBuilder: (_) => [
        if (profile != null)
          const PopupMenuItem(
            value: 'profile',
            child: ListTile(
              leading: Icon(Icons.person_outline_rounded),
              title: Text('My Profile'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout_rounded, color: AppColors.error),
            title: Text('Logout', style: TextStyle(color: AppColors.error)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WebTokens.gap,
          vertical: WebTokens.gap / 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: ClipOval(
                child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? Image.network(
                        user.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _initialsAvatar(initials),
                      )
                    : _initialsAvatar(initials),
              ),
            ),
            if (isWide) ...[
              const SizedBox(width: WebTokens.gap),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textWhite : AppColors.textDark,
                    ),
                  ),
                  Text(
                    user.role.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryOrange,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: WebTokens.gap / 2),
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: isDark
                    ? AppColors.textWhiteMuted
                    : AppColors.textDarkMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Nav panel (drawer / sidebar) ────────────────────────────────────────

  /// Renders the app's navigation as either a slide-out [Drawer] (phones —
  /// [isPermanent] false) or a permanently visible side panel next to the
  /// body (desktop/web — [isPermanent] true). Both share one content tree so
  /// the nav never drifts between the two layouts.
  ///
  Widget _buildNavPanel(
    BuildContext context,
    bool isDark,
    List<_NavModule> modules,
    List<_NavPage> pages, {
    required bool isPermanent,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    // A slide-out Drawer has its own local-history entry that Navigator.pop
    // closes; a permanent panel has none, so popping there would instead pop
    // the real screen underneath. Route every "close the nav" tap through
    // this so it's a no-op when the panel is permanent.
    void close() {
      if (!isPermanent) Navigator.pop(context);
    }

    void openPage(_NavPage page) {
      if (page.closeFirst) close();
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: RouteSettings(name: page.label),
          builder: (_) => page.builder(),
        ),
      );
    }

    Widget pageItem(_NavPage page) => _buildDrawerItem(
      page.icon,
      page.label,
      () => openPage(page),
      isDark,
    );

    final navPages = pages.where((p) => p.section == null);
    final adminPages = pages.where((p) => p.section == _sectionAdmin);
    final accountPages = pages.where((p) => p.section == _sectionAccount);

    final items = <Widget>[
      if (_isKitchen) ...[
        _buildDrawerSection('KITCHEN', isDark),
        _buildDrawerItem(
          Icons.restaurant_rounded,
          'Kitchen Display',
          close,
          isDark,
          isSelected: true,
        ),
      ] else ...[
        _buildDrawerSection('NAVIGATION', isDark),
        ...modules.asMap().entries.map(
          (e) => _buildDrawerItem(
            e.value.icon,
            e.value.label,
            () {
              setState(() => _selectedNavIndex = e.key);
              close();
            },
            isDark,
            isSelected: _selectedNavIndex == e.key,
          ),
        ),
        ...navPages.map(pageItem),
        if (adminPages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildDrawerSection('ADMIN MASTERS', isDark),
          ...adminPages.map(pageItem),
        ],
      ],
      const SizedBox(height: 12),
      _buildDrawerSection('ACCOUNT', isDark),
      ...accountPages.map(pageItem),
      _buildDrawerItem(
        Icons.logout_rounded,
        'Logout',
        () => ref.read(authStateProvider.notifier).signOut(),
        isDark,
        isError: true,
      ),
    ];

    final list = ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      children: items,
    );

    final content = SafeArea(
        child: Container(
            margin: EdgeInsets.only(
              top: 12,
              bottom: 12,
              left: 12,
              right: isPermanent ? 12 : 0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(5, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        isDark
                            ? const Color(0xFF1E1E1E).withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.85),
                        isDark
                            ? const Color(0xFF121212).withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDrawerUserHeader(isDark),
                      Expanded(child: list),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    if (isPermanent) return content;

    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      child: Drawer(width: isMobile ? 260.0 : 280.0, child: content),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, ${local.year}  $h:$m $ampm';
  }

  Widget _buildDrawerUserHeader(bool isDark) {
    final user = widget.user;
    final initials = user.fullName.isNotEmpty
        ? user.fullName
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0] : '')
              .join()
              .toUpperCase()
        : '?';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryAmber, AppColors.primaryOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Rasabhojan',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // User Profile Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryOrange.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? Image.network(
                          user.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _initialsAvatar(initials),
                        )
                      : _initialsAvatar(initials),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          user.role.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryOrange,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (user.lastLogin != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatDateTime(user.lastLogin!),
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                color: isDark
                                    ? AppColors.textWhiteMuted
                                    : AppColors.textDarkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initialsAvatar(String initials) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primaryAmber, AppColors.primaryOrange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Text(
        initials,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
  Widget _buildDrawerSection(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isDark
              ? AppColors.textWhiteMuted.withValues(alpha: 0.5)
              : AppColors.textDarkMuted.withValues(alpha: 0.5),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap,
    bool isDark, {
    bool isError = false,
    bool isSelected = false,
  }) {
    final activeColor = isDark
        ? AppColors.primaryAmber
        : AppColors.primaryOrange;
    final contentColor = isError
        ? AppColors.error
        : (isSelected
              ? activeColor
              : (isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: activeColor.withValues(alpha: 0.05),
          splashColor: activeColor.withValues(alpha: 0.1),
          highlightColor: activeColor.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isSelected
                  ? activeColor.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: Stack(
              children: [
                if (isSelected)
                  Positioned(
                    left: 0,
                    top: 10,
                    bottom: 10,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: contentColor),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isError
                                ? AppColors.error
                                : (isSelected
                                      ? (isDark
                                            ? Colors.white
                                            : AppColors.textDark)
                                      : (isDark
                                            ? AppColors.textWhiteMuted
                                            : AppColors.textDarkMuted)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavModule {
  final IconData icon;
  final String label;
  final Widget screen;
  const _NavModule(this.icon, this.label, this.screen);

  /// This module as a web-shell destination (labels are unique per shell).
  _NavPage get asPage => _NavPage(
    id: 'module:$label',
    icon: icon,
    label: label,
    builder: () => screen,
  );
}

/// A non-module nav destination (admin masters, Kitchen Monitor, profile).
/// Native builds push [builder] full-screen; the web shell opens it in its
/// content navigator. [section] is the breadcrumb/grouping label (null =
/// main navigation); [closeFirst] preserves which native drawer items closed
/// the drawer before pushing.
class _NavPage {
  final String id;
  final IconData icon;
  final String label;
  final String? section;
  final bool closeFirst;
  final Widget Function() builder;

  const _NavPage({
    required this.id,
    required this.icon,
    required this.label,
    required this.builder,
    this.section,
    this.closeFirst = false,
  });
}
