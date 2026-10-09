import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_app_bar.dart';
import '../../../core/widgets/breadcrumbs.dart';
import '../../../core/widgets/web_kit.dart';
import '../../../core/widgets/web_layout.dart';
import '../../../core/backend/backend.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/network_check.dart' as net;
import '../../../core/widgets/app_data_table.dart';
import '../../../core/widgets/window_class.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

// ─── Role accent colors & icons ──────────────────────────────────────────────

Color _roleColor(String role) => switch (role.toLowerCase()) {
  'admin' => const Color(0xFFD32F2F),
  'manager' => const Color(0xFF5C6BC0),
  'staff' => const Color(0xFF388E3C),
  'kitchen_master' => const Color(0xFF00897B),
  _ => AppColors.primaryAmber,
};

IconData _roleIcon(String role) => switch (role.toLowerCase()) {
  'admin' => Icons.admin_panel_settings_rounded,
  'manager' => Icons.manage_accounts_rounded,
  'staff' => Icons.badge_rounded,
  'kitchen_master' => Icons.restaurant_rounded,
  _ => Icons.person_rounded,
};

// ─── Screen ──────────────────────────────────────────────────────────────────

class RoleMasterScreen extends ConsumerStatefulWidget {
  final String companyId;
  const RoleMasterScreen({super.key, required this.companyId});

  @override
  ConsumerState<RoleMasterScreen> createState() => _RoleMasterScreenState();
}

class _RoleMasterScreenState extends ConsumerState<RoleMasterScreen> {
  bool _isLoading = false;
  List<AppRole> _roles = [];
  bool _isEditing = false;
  AppRole? _selectedRole;

  // Form state
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isActive = true;

  // Permission toggles
  bool _canViewDashboard = false;
  bool _canCreateBill = false;
  bool _canEditBill = false;
  bool _canCancelBill = false;
  bool _canApplyDiscount = false;
  bool _canManageItems = false;
  bool _canManageTables = false;
  bool _canViewReports = false;
  bool _canManageUsers = false;
  bool _canManageSettings = false;
  bool _canVoidItems = false;
  bool _canManageStock = false;
  bool _canManageRoles = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ─── Network ───────────────────────────────────────────────────────────────

  Future<bool> _checkNet() async {
    if (!await net.hasNetwork()) {
      _showError('No internet connection. Check your network and retry.');
      return false;
    }
    return true;
  }

  // ─── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadRoles() async {
    if (_isLoading) return;
    if (!await _checkNet()) return;
    setState(() => _isLoading = true);
    try {
      final data = await Backend.getRoles(
        widget.companyId,
      ).timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(
          () => _roles = data.map((e) => AppRole.fromJson(e)).toList(),
        );
      }
    } on TimeoutException {
      _showError('Request timed out.', onRetry: _loadRoles);
    } on SocketException {
      _showError('Network error.', onRetry: _loadRoles);
    } catch (e) {
      _showError('Failed to load roles: $e', onRetry: _loadRoles);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCreate() {
    setState(() {
      _isEditing = true;
      _selectedRole = null;
      _clearForm();
    });
  }

  void _startEdit(AppRole role) {
    setState(() {
      _isEditing = true;
      _selectedRole = role;
      _nameController.text = role.roleName;
      _displayNameController.text = role.displayName;
      _descController.text = role.description ?? '';
      _isActive = role.isActive;
      _canViewDashboard = role.canViewDashboard;
      _canCreateBill = role.canCreateBill;
      _canEditBill = role.canEditBill;
      _canCancelBill = role.canCancelBill;
      _canApplyDiscount = role.canApplyDiscount;
      _canManageItems = role.canManageItems;
      _canManageTables = role.canManageTables;
      _canViewReports = role.canViewReports;
      _canManageUsers = role.canManageUsers;
      _canManageSettings = role.canManageSettings;
      _canVoidItems = role.canVoidItems;
      _canManageStock = role.canManageStock;
      _canManageRoles = role.canManageRoles;
    });
  }

  void _clearForm() {
    _nameController.clear();
    _displayNameController.clear();
    _descController.clear();
    _isActive = true;
    _canViewDashboard = false;
    _canCreateBill = false;
    _canEditBill = false;
    _canCancelBill = false;
    _canApplyDiscount = false;
    _canManageItems = false;
    _canManageTables = false;
    _canViewReports = false;
    _canManageUsers = false;
    _canManageSettings = false;
    _canVoidItems = false;
    _canManageStock = false;
    _canManageRoles = false;
  }

  void _grantAll(bool value) {
    setState(() {
      _canViewDashboard = value;
      _canCreateBill = value;
      _canEditBill = value;
      _canCancelBill = value;
      _canApplyDiscount = value;
      _canManageItems = value;
      _canManageTables = value;
      _canViewReports = value;
      _canManageUsers = value;
      _canManageSettings = value;
      _canVoidItems = value;
      _canManageStock = value;
      _canManageRoles = value;
    });
  }

  Future<void> _saveRole() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!await _checkNet()) return;
    setState(() => _isLoading = true);
    try {
      final roleId = _selectedRole?.id ?? const Uuid().v4();
      final data = {
        'id': roleId,
        'company_id': widget.companyId,
        'role_name': _nameController.text.trim().toLowerCase().replaceAll(' ', '_'),
        'display_name': _displayNameController.text.trim(),
        'description': _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        'is_system': _selectedRole?.isSystem ?? false,
        'is_active': _isActive,
        'can_view_dashboard': _canViewDashboard,
        'can_create_bill': _canCreateBill,
        'can_edit_bill': _canEditBill,
        'can_cancel_bill': _canCancelBill,
        'can_apply_discount': _canApplyDiscount,
        'can_manage_items': _canManageItems,
        'can_manage_tables': _canManageTables,
        'can_view_reports': _canViewReports,
        'can_manage_users': _canManageUsers,
        'can_manage_settings': _canManageSettings,
        'can_void_items': _canVoidItems,
        'can_manage_stock': _canManageStock,
        'can_manage_roles': _canManageRoles,
      };
      await Backend.upsertRole(data).timeout(const Duration(seconds: 20));
      if (mounted) {
        _showSuccess(
          _selectedRole == null ? 'Role created.' : 'Role updated.',
        );
        // Invalidate the roles provider cache so dropdowns reload.
        ref.invalidate(rolesProvider(widget.companyId));
        setState(() => _isEditing = false);
        _loadRoles();
      }
    } on TimeoutException {
      _showError('Request timed out.', onRetry: _saveRole);
    } on SocketException {
      _showError('Network error.', onRetry: _saveRole);
    } catch (e) {
      _showError('Failed to save: $e', onRetry: _saveRole);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRole(AppRole role) async {
    if (role.isSystem) {
      _showError('System roles cannot be deleted.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Role',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(ctx).textTheme.bodyMedium?.color,
            ),
            children: [
              const TextSpan(text: 'Delete the '),
              TextSpan(
                text: role.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text: ' role? Users currently assigned this role will keep their '
                    'existing permission row but will lose role-based defaults.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Theme.of(ctx).textTheme.bodySmall?.color),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await _checkNet()) return;
    setState(() => _isLoading = true);
    try {
      await Backend.deleteRole(role.id).timeout(const Duration(seconds: 10));
      _showSuccess('Role deleted.');
      ref.invalidate(rolesProvider(widget.companyId));
      _loadRoles();
    } on TimeoutException {
      _showError('Request timed out.', onRetry: () => _deleteRole(role));
    } on SocketException {
      _showError('Network error.', onRetry: () => _deleteRole(role));
    } catch (e) {
      _showError('Failed: $e', onRetry: () => _deleteRole(role));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Feedback ──────────────────────────────────────────────────────────────

  void _showSuccess(String msg) {
    if (!mounted) return;
    AppFeedback.success(context, msg);
  }

  void _showError(String msg, {VoidCallback? onRetry}) {
    if (!mounted) return;
    AppFeedback.toast(context, msg, isError: true, onRetry: onRetry);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final webWide = WebLayout.enabled && context.isWideWindow;

    return Scaffold(
      backgroundColor: webWide
          ? WebPalette.canvas(isDark)
          : (isDark ? AppColors.darkBg : const Color(0xFFF0F2F5)),
      appBar: _buildAppBar(isDark),
      body: BreadcrumbTail(
        crumbs: _isEditing ? [Crumb(_pageTitle)] : const [],
        onBaseTap: _isEditing ? () => setState(() => _isEditing = false) : null,
        child: _isLoading && !_isEditing
            ? const Center(child: CircularProgressIndicator())
            : webWide
            ? WebMasterDetail(
                master: _buildList(isDark),
                detail: _isEditing
                    ? WebSidePanel(
                        width: 560,
                        title: _pageTitle,
                        subtitle: _selectedRole?.displayName ??
                            'Define permissions for this role',
                        onClose: () => setState(() => _isEditing = false),
                        child: _buildEditor(isDark),
                      )
                    : null,
              )
            : _isEditing
            ? _buildEditor(isDark)
            : _buildList(isDark),
      ),
    );
  }

  String get _pageTitle =>
      _isEditing ? (_selectedRole == null ? 'New Role' : 'Edit Role') : 'Role Master';

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AdaptiveAppBar(
      title: _pageTitle,
      webActions: _isEditing
          ? [
              TextButton(
                onPressed: _isLoading ? null : () => setState(() => _isEditing = false),
                child: const Text('Cancel'),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                WebHeaderButton(
                  icon: Icons.check_rounded,
                  label: 'Save',
                  onPressed: _saveRole,
                ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _isLoading ? null : _loadRoles,
                tooltip: 'Refresh',
              ),
              WebHeaderButton(
                icon: Icons.add_rounded,
                label: 'Add Role',
                onPressed: _startCreate,
              ),
            ],
      mobile: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        title: Text(
          _pageTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        leading: _isEditing
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _isEditing = false),
              )
            : null,
        actions: [
          if (_isEditing)
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.check_rounded),
                    onPressed: _saveRole,
                    tooltip: 'Save',
                  )
          else ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _isLoading ? null : _loadRoles,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _startCreate,
              tooltip: 'Add Role',
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
    );
  }

  // ─── List ──────────────────────────────────────────────────────────────────

  Widget _buildList(bool isDark) {
    if (_roles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 48,
                color: isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No roles yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _startCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text('Create first role', style: GoogleFonts.inter()),
            ),
          ],
        ),
      );
    }

    if (WebLayout.enabled && context.isWideWindow) {
      return _buildWebList(isDark);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _buildStatsHeader(isDark),
        const SizedBox(height: 16),
        ..._roles.map((r) => _buildRoleCard(r, isDark)),
      ],
    );
  }

  Widget _buildWebList(bool isDark) {
    final activeCount = _roles.where((r) => r.isActive).length;
    return WebPageBody(
      onRefresh: _loadRoles,
      children: [
        WebResponsiveRow(
          minChildWidth: 200,
          children: [
            WebStatTile(
              label: 'Total roles',
              value: '${_roles.length}',
              icon: Icons.shield_rounded,
            ),
            WebStatTile(
              label: 'Active',
              value: '$activeCount',
              icon: Icons.verified_rounded,
              accent: AppColors.tableFree,
            ),
            WebStatTile(
              label: 'System',
              value: '${_roles.where((r) => r.isSystem).length}',
              icon: Icons.lock_rounded,
              accent: AppColors.info,
              caption: 'Cannot be deleted',
            ),
          ],
        ),
        const SizedBox(height: WebSpace.xl),
        AppDataTable<AppRole>(
          title: 'Roles',
          rows: _roles,
          searchText: (r) => '${r.roleName} ${r.displayName} ${r.description ?? ''}',
          onRowTap: _startEdit,
          actions: [
            AppRowAction<AppRole>('Edit role', Icons.edit_outlined, _startEdit),
            AppRowAction<AppRole>(
              'Delete',
              Icons.delete_rounded,
              (r) => _deleteRole(r),
            ),
          ],
          columns: [
            AppColumn<AppRole>(
              label: 'Role',
              value: (r) => r.displayName,
              size: ColumnSize.L,
              cell: (r) => Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _roleColor(r.roleName).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_roleIcon(r.roleName), size: 14, color: _roleColor(r.roleName)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.displayName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          r.roleName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: WebPalette.muted(isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppColumn<AppRole>(
              label: 'Permissions',
              value: (r) => _countPerms(r).toString(),
              size: ColumnSize.S,
              cell: (r) {
                final count = _countPerms(r);
                final total = 13;
                return Text(
                  '$count / $total',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: count == total ? AppColors.tableFree : null,
                  ),
                );
              },
            ),
            AppColumn<AppRole>(
              label: 'Type',
              value: (r) => r.isSystem ? 'System' : 'Custom',
              size: ColumnSize.S,
              cell: (r) => r.isSystem
                  ? const WebStatusPill(label: 'System', color: AppColors.info, icon: Icons.lock_rounded)
                  : const WebStatusPill(label: 'Custom', color: AppColors.primaryOrange, icon: Icons.tune_rounded),
            ),
            AppColumn<AppRole>(
              label: 'Status',
              value: (r) => r.isActive ? 'ACTIVE' : 'INACTIVE',
              size: ColumnSize.S,
              cell: (r) => r.isActive
                  ? const WebStatusPill(label: 'Active', color: AppColors.tableFree, icon: Icons.check_rounded)
                  : const WebStatusPill(label: 'Inactive', color: AppColors.error, icon: Icons.block_rounded),
            ),
          ],
        ),
      ],
    );
  }

  int _countPerms(AppRole r) => [
    r.canViewDashboard, r.canCreateBill, r.canEditBill, r.canCancelBill,
    r.canApplyDiscount, r.canManageItems, r.canManageTables, r.canViewReports,
    r.canManageUsers, r.canManageSettings, r.canVoidItems, r.canManageStock,
    r.canManageRoles,
  ].where((v) => v).length;

  Widget _buildStatsHeader(bool isDark) {
    final activeCount = _roles.where((r) => r.isActive).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryOrange.withValues(alpha: 0.85),
            AppColors.primaryAmber.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _statItem('Total', _roles.length.toString(), Icons.shield_rounded)),
          _statDiv(),
          Expanded(child: _statItem('Active', activeCount.toString(), Icons.check_circle_rounded)),
          _statDiv(),
          Expanded(child: _statItem('System', '${_roles.where((r) => r.isSystem).length}', Icons.lock_rounded)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) => Column(
    children: [
      Icon(icon, size: 20, color: Colors.white70),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
      Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70)),
    ],
  );

  Widget _statDiv() => Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.3));

  Widget _buildRoleCard(AppRole role, bool isDark) {
    final rc = _roleColor(role.roleName);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: rc),
              Expanded(
                child: InkWell(
                  onTap: () => _startEdit(role),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: rc.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_roleIcon(role.roleName), size: 22, color: rc),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      role.displayName,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? AppColors.textWhite : AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  if (role.isSystem)
                                    _chip('SYSTEM', AppColors.info),
                                  if (!role.isActive) ...[
                                    const SizedBox(width: 6),
                                    _chip('INACTIVE', AppColors.error),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_countPerms(role)} / 13 permissions  ·  ${role.roleName}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted,
                                ),
                              ),
                              if (role.description != null && role.description!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  role.description!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _startEdit(role);
                            if (v == 'delete') _deleteRole(role);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16, color: isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted),
                                  const SizedBox(width: 10),
                                  Text('Edit Role', style: GoogleFonts.inter(fontSize: 13)),
                                ],
                              ),
                            ),
                            if (!role.isSystem)
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                                    const SizedBox(width: 10),
                                    Text('Delete', style: GoogleFonts.inter(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                          ],
                          icon: Icon(Icons.more_vert_rounded, size: 20, color: isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    margin: const EdgeInsets.only(left: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: color),
    ),
  );

  // ─── Editor ────────────────────────────────────────────────────────────────

  Widget _buildEditor(bool isDark) {
    final mq = MediaQuery.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + mq.padding.bottom),
        children: [
          // ── Basic Info ──────────────────────────────────
          _EditorCard(
            title: 'Role Details',
            icon: Icons.shield_rounded,
            accentColor: AppColors.primaryOrange,
            isDark: isDark,
            children: [
              _field(
                controller: _displayNameController,
                label: 'Display Name',
                icon: Icons.label_rounded,
                isDark: isDark,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                hint: 'e.g. Kitchen Master',
                onChanged: (v) {
                  // Auto-fill role_name slug on create.
                  if (_selectedRole == null) {
                    _nameController.text =
                        v.trim().toLowerCase().replaceAll(' ', '_');
                  }
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _nameController,
                label: 'Role Name (slug)',
                icon: Icons.code_rounded,
                isDark: isDark,
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(v.trim())) {
                    return 'Lowercase letters, digits and underscores only';
                  }
                  return null;
                },
                hint: 'e.g. kitchen_master',
                // System roles: slug cannot change.
                readOnly: _selectedRole?.isSystem ?? false,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _descController,
                label: 'Description (optional)',
                icon: Icons.notes_rounded,
                isDark: isDark,
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              _activeToggle(isDark),
            ],
          ),
          const SizedBox(height: 16),

          // ── Quick actions ───────────────────────────────
          Row(
            children: [
              Expanded(
                child: _quickBtn('Grant All', Icons.done_all_rounded, AppColors.success, isDark, () => _grantAll(true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickBtn('Revoke All', Icons.remove_done_rounded, AppColors.error, isDark, () => _grantAll(false)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Permissions ─────────────────────────────────
          _PermGroup(
            title: 'Billing',
            icon: Icons.receipt_long_rounded,
            accentColor: AppColors.primaryOrange,
            isDark: isDark,
            items: [
              _PermItem('Create Bills / KOTs', Icons.add_circle_outline_rounded, _canCreateBill, (v) => setState(() => _canCreateBill = v)),
              _PermItem('Edit Bill Items', Icons.edit_rounded, _canEditBill, (v) => setState(() => _canEditBill = v)),
              _PermItem('Void Items', Icons.remove_circle_outline_rounded, _canVoidItems, (v) => setState(() => _canVoidItems = v)),
              _PermItem('Cancel Bills', Icons.cancel_outlined, _canCancelBill, (v) => setState(() => _canCancelBill = v)),
              _PermItem('Apply Discounts', Icons.discount_rounded, _canApplyDiscount, (v) => setState(() => _canApplyDiscount = v)),
            ],
          ),
          const SizedBox(height: 14),

          _PermGroup(
            title: 'Access',
            icon: Icons.dashboard_rounded,
            accentColor: AppColors.info,
            isDark: isDark,
            items: [
              _PermItem('View Dashboard', Icons.bar_chart_rounded, _canViewDashboard, (v) => setState(() => _canViewDashboard = v)),
              _PermItem('View Reports', Icons.assessment_rounded, _canViewReports, (v) => setState(() => _canViewReports = v)),
              _PermItem('Manage Tables', Icons.table_restaurant_rounded, _canManageTables, (v) => setState(() => _canManageTables = v)),
            ],
          ),
          const SizedBox(height: 14),

          _PermGroup(
            title: 'Administration',
            icon: Icons.admin_panel_settings_rounded,
            accentColor: const Color(0xFF5C6BC0),
            isDark: isDark,
            items: [
              _PermItem('Manage Menu Items', Icons.restaurant_menu_rounded, _canManageItems, (v) => setState(() => _canManageItems = v)),
              _PermItem('Manage Users', Icons.people_rounded, _canManageUsers, (v) => setState(() => _canManageUsers = v)),
              _PermItem('Manage Roles (RBAC)', Icons.shield_rounded, _canManageRoles, (v) => setState(() => _canManageRoles = v)),
              _PermItem('System Settings', Icons.settings_rounded, _canManageSettings, (v) => setState(() => _canManageSettings = v)),
            ],
          ),
          const SizedBox(height: 14),

          _PermGroup(
            title: 'Inventory',
            icon: Icons.warehouse_rounded,
            accentColor: AppColors.accentTeal,
            isDark: isDark,
            items: [
              _PermItem('Manage Stock / Inventory', Icons.inventory_rounded, _canManageStock, (v) => setState(() => _canManageStock = v)),
            ],
          ),
          const SizedBox(height: 24),

          // ── Save button ─────────────────────────────────
          SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveRole,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? LinearGradient(colors: [
                            AppColors.primaryOrange.withValues(alpha: 0.4),
                            AppColors.primaryAmber.withValues(alpha: 0.4),
                          ])
                        : const LinearGradient(
                            colors: [AppColors.primaryOrange, AppColors.primaryAmber],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                _selectedRole == null ? 'CREATE ROLE' : 'SAVE CHANGES',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeToggle(bool isDark) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Role',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textWhite : AppColors.textDark),
            ),
            const SizedBox(height: 2),
            Text(
              'Inactive roles cannot be assigned to new users',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted,
              ),
            ),
          ],
        ),
      ),
      Switch(
        value: _isActive,
        onChanged: (v) => setState(() => _isActive = v),
        activeThumbColor: AppColors.success,
        activeTrackColor: AppColors.success.withValues(alpha: 0.35),
        inactiveThumbColor: AppColors.error,
        inactiveTrackColor: AppColors.error.withValues(alpha: 0.25),
      ),
    ],
  );

  Widget _quickBtn(String label, IconData icon, Color color, bool isDark, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? Function(String?)? validator,
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      validator: validator,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(fontSize: 13),
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryAmber, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        filled: true,
        fillColor: readOnly
            ? (isDark ? AppColors.darkBg.withValues(alpha: 0.5) : const Color(0xFFF5F5F5))
            : (isDark ? AppColors.darkBg : Colors.white),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ─── Editor Card ─────────────────────────────────────────────────────────────

class _EditorCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final List<Widget> children;

  const _EditorCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.1 : 0.06),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  left: BorderSide(color: accentColor, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Perm Group ───────────────────────────────────────────────────────────────

class _PermItem {
  final String title;
  final IconData icon;
  final bool value;
  final void Function(bool) onChanged;
  const _PermItem(this.title, this.icon, this.value, this.onChanged);
}

class _PermGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final List<_PermItem> items;

  const _PermGroup({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.1 : 0.06),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  left: BorderSide(color: accentColor, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
            ...items.asMap().entries.map((e) {
              final idx = e.key;
              final item = e.value;
              return Column(
                children: [
                  if (idx > 0)
                    Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon, size: 14, color: accentColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.textWhite : AppColors.textDark,
                            ),
                          ),
                        ),
                        Switch(
                          value: item.value,
                          onChanged: item.onChanged,
                          activeThumbColor: accentColor,
                          activeTrackColor: accentColor.withValues(alpha: 0.35),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
