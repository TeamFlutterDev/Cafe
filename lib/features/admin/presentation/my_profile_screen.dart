import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/web_kit.dart';
import '../../../core/widgets/web_layout.dart';
import '../../../core/widgets/window_class.dart';
import '../../../core/backend/backend.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/network_check.dart' as net;
import '../../../models/models.dart';

// ─── Role helpers ─────────────────────────────────────────────────────────────

Color _roleColor(String role) => switch (role.toLowerCase()) {
  'admin' => const Color(0xFFD32F2F),
  'manager' => const Color(0xFF5C6BC0),
  'cashier' => const Color(0xFF388E3C),
  'waiter' => const Color(0xFFFF8F00),
  'kitchen' => const Color(0xFF00897B),
  _ => AppColors.primaryAmber,
};

IconData _roleIcon(String role) => switch (role.toLowerCase()) {
  'admin' => Icons.admin_panel_settings_rounded,
  'manager' => Icons.manage_accounts_rounded,
  'cashier' => Icons.point_of_sale_rounded,
  'waiter' => Icons.room_service_rounded,
  'kitchen' => Icons.restaurant_rounded,
  _ => Icons.person_rounded,
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class MyProfileScreen extends StatefulWidget {
  final UserProfile user;
  const MyProfileScreen({super.key, required this.user});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isLoading = false;
  bool _isEditing = false;
  UserPermission? _permissions;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();

  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.user;
    _loadPermissions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  // ─── Network ──────────────────────────────────────────────────────────────

  Future<bool> _hasNetwork() => net.hasNetwork();

  Future<bool> _checkNetworkAndWarn() async {
    if (!await _hasNetwork()) {
      _showError('No internet connection. Check your network and retry.');
      return false;
    }
    return true;
  }

  void _showError(String msg, {VoidCallback? onRetry}) {
    if (!mounted) return;
    AppFeedback.toast(context, msg, isError: true, onRetry: onRetry);
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    AppFeedback.success(context, msg);
  }

  // ─── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadPermissions() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (!await _checkNetworkAndWarn()) return;
      final data = await Backend.getUserPermissions(
        _profile.id,
      ).timeout(const Duration(seconds: 10));
      if (data != null && mounted) {
        setState(() => _permissions = UserPermission.fromJson(data));
      }
    } on TimeoutException {
      _showError('Request timed out.', onRetry: _loadPermissions);
    } on SocketException {
      _showError('Network error.', onRetry: _loadPermissions);
    } catch (e) {
      _showError('Failed to load: $e', onRetry: _loadPermissions);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEdit() {
    _nameController.text = _profile.fullName;
    _phoneController.text = _profile.phone ?? '';
    _emailController.text = _profile.email ?? '';
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _pickedImage = null;
      _pickedImageBytes = null;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = picked;
      _pickedImageBytes = bytes;
    });
  }

  Future<void> _saveProfile() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!await _checkNetworkAndWarn()) return;

    setState(() => _isLoading = true);
    try {
      String? newAvatarUrl = _profile.avatarUrl;

      if (_pickedImage != null && _pickedImageBytes != null) {
        final ext = _pickedImage!.name.split('.').last.toLowerCase();
        newAvatarUrl = await Backend.uploadAvatar(
          _profile.id,
          _pickedImageBytes!,
          ext,
        ).timeout(const Duration(seconds: 30));
      }

      await Backend.updateOwnProfile(
        userId: _profile.id,
        userName: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        avatarUrl: newAvatarUrl,
      ).timeout(const Duration(seconds: 10));

      final updated = UserProfile(
        id: _profile.id,
        companyId: _profile.companyId,
        role: _profile.role,
        fullName: _nameController.text.trim(),
        employeeCode: _profile.employeeCode,
        username: _profile.username,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        avatarUrl: newAvatarUrl,
        isActive: _profile.isActive,
        createdAt: _profile.createdAt,
      );

      if (mounted) {
        setState(() {
          _profile = updated;
          _pickedImage = null;
          _pickedImageBytes = null;
          _isEditing = false;
        });
        _showSuccess('Profile updated successfully');
      }
    } on TimeoutException {
      _showError('Request timed out.', onRetry: _saveProfile);
    } on SocketException {
      _showError('Network error.', onRetry: _saveProfile);
    } catch (e) {
      _showError('Failed to save: $e', onRetry: _saveProfile);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rc = _roleColor(_profile.role);

    // Desktop web: account-settings page layout.
    if (WebLayout.enabled && context.isWideWindow) return _buildWeb(isDark, rc);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          _buildHeader(isDark, rc),
          Expanded(
            child: _isEditing
                ? _buildEditForm(isDark, rc)
                : _buildViewBody(isDark, rc),
          ),
        ],
      ),
    );
  }

  // ─── Web layout ────────────────────────────────────────────────────────────

  String get _initials => _profile.fullName.isNotEmpty
      ? _profile.fullName
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0] : '')
            .join()
            .toUpperCase()
      : '?';

  Widget _buildWeb(bool isDark, Color rc) {
    return Scaffold(
      backgroundColor: WebPalette.canvas(isDark),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWebHeaderBar(isDark),
          Expanded(
            child: Form(
              key: _formKey,
              child: WebPageBody(
                maxWidth: 1200,
                children: [
                  _buildWebHero(isDark, rc),
                  const SizedBox(height: WebSpace.xl),
                  LayoutBuilder(
                    builder: (context, c) {
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildWebPersonalCard(isDark, rc),
                          const SizedBox(height: WebSpace.lg),
                          _buildWebContactCard(isDark, rc),
                        ],
                      );
                      final perms = _buildWebPermissionsCard(isDark);
                      if (c.maxWidth < 900) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            details,
                            const SizedBox(height: WebSpace.lg),
                            perms,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: details),
                          const SizedBox(width: WebSpace.lg),
                          Expanded(flex: 2, child: perms),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebHeaderBar(bool isDark) {
    return Container(
      height: WebTokens.pageHeaderHeight + 8,
      padding: const EdgeInsets.symmetric(horizontal: WebTokens.gutter),
      decoration: BoxDecoration(
        color: WebPalette.surface(isDark),
        border: Border(bottom: BorderSide(color: WebPalette.border(isDark))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Profile',
                  style: GoogleFonts.inter(
                    fontSize: WebTokens.pageTitleFontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: WebPalette.text(isDark),
                  ),
                ),
                Text(
                  _isEditing
                      ? 'Update your name, photo and contact details'
                      : 'Your account details and what you can access',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: WebPalette.muted(isDark),
                  ),
                ),
              ],
            ),
          ),
          if (_isEditing) ...[
            TextButton(
              onPressed: _isLoading ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: WebSpace.sm),
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveProfile,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_isLoading ? 'Saving…' : 'Save changes'),
            ),
          ] else
            FilledButton.icon(
              onPressed: _startEdit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit profile'),
            ),
        ],
      ),
    );
  }

  Widget _webAvatar(Color rc, double size) {
    final hasImage = _pickedImageBytes != null;
    final hasAvatar =
        _profile.avatarUrl != null && _profile.avatarUrl!.isNotEmpty;
    final image = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
            : hasAvatar
            ? Image.network(
                _profile.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _avatarFallback(rc, _initials),
              )
            : _avatarFallback(rc, _initials),
      ),
    );

    final framed = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: image,
    );

    if (!_isEditing) return framed;

    // Edit mode: the whole avatar is the "change photo" button.
    return Tooltip(
      message: 'Change photo',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              framed,
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebHero(bool isDark, Color rc) {
    Widget fact(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(left: WebSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: WebPalette.muted(isDark)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: WebPalette.muted(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: WebPalette.text(isDark),
            ),
          ),
        ],
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WebPalette.surface(isDark),
        borderRadius: BorderRadius.circular(WebSpace.radius),
        border: Border.all(color: WebPalette.border(isDark)),
      ),
      child: Stack(
        children: [
          // Role-tinted banner
          Container(
            height: 104,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  rc.withValues(alpha: isDark ? 0.45 : 0.85),
                  rc.withValues(alpha: isDark ? 0.2 : 0.45),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WebSpace.xxl,
              56,
              WebSpace.xxl,
              WebSpace.xl,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _webAvatar(rc, 112),
                const SizedBox(width: WebSpace.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: WebPalette.text(isDark),
                        ),
                      ),
                      const SizedBox(height: WebSpace.sm),
                      Wrap(
                        spacing: WebSpace.sm,
                        runSpacing: WebSpace.xs,
                        children: [
                          WebStatusPill(
                            label: _profile.role.toUpperCase(),
                            color: rc,
                            icon: _roleIcon(_profile.role),
                          ),
                          _profile.isActive
                              ? const WebStatusPill(
                                  label: 'Active',
                                  color: AppColors.tableFree,
                                  icon: Icons.check_rounded,
                                )
                              : const WebStatusPill(
                                  label: 'Inactive',
                                  color: AppColors.error,
                                  icon: Icons.block_rounded,
                                ),
                          WebStatusPill(
                            label: _profile.employeeCode,
                            color: WebPalette.muted(isDark),
                            icon: Icons.tag_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_profile.lastLogin != null)
                  fact(
                    Icons.login_rounded,
                    'Last login',
                    _formatDateTime(_profile.lastLogin!),
                  ),
                if (_profile.createdAt != null)
                  fact(
                    Icons.calendar_today_outlined,
                    'Member since',
                    _formatDate(_profile.createdAt!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Label/value pair used in the view-mode grids.
  Widget _webDetail(
    bool isDark,
    IconData icon,
    String label,
    String? value,
  ) {
    final missing = value == null || value.isEmpty;
    return Container(
      padding: const EdgeInsets.all(WebSpace.md + 2),
      decoration: BoxDecoration(
        color: WebPalette.subtle(isDark),
        borderRadius: BorderRadius.circular(WebSpace.radiusSm),
        border: Border.all(color: WebPalette.border(isDark)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: WebPalette.muted(isDark)),
          const SizedBox(width: WebSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: WebPalette.muted(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  missing ? 'Not set' : value,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: missing ? FontWeight.w400 : FontWeight.w600,
                    fontStyle: missing ? FontStyle.italic : FontStyle.normal,
                    color: missing
                        ? WebPalette.muted(isDark)
                        : WebPalette.text(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebPersonalCard(bool isDark, Color rc) {
    return WebCard(
      title: 'Personal information',
      subtitle: _isEditing
          ? 'Employee code, username and role are managed by an admin'
          : 'How you appear to your team',
      icon: Icons.badge_outlined,
      child: _isEditing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  nextFocus: _phoneFocus,
                  label: 'Full name',
                  icon: Icons.person_outline_rounded,
                  isDark: isDark,
                  rc: rc,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: WebSpace.lg),
                WebResponsiveRow(
                  minChildWidth: 200,
                  spacing: WebSpace.md,
                  children: [
                    _webDetail(isDark, Icons.tag_rounded, 'Employee code',
                        _profile.employeeCode),
                    _webDetail(
                      isDark,
                      Icons.alternate_email_rounded,
                      'Username',
                      _profile.username == null ? null : '@${_profile.username}',
                    ),
                    _webDetail(isDark, _roleIcon(_profile.role), 'Role',
                        _profile.role.toUpperCase()),
                  ],
                ),
              ],
            )
          : WebResponsiveRow(
              minChildWidth: 220,
              spacing: WebSpace.md,
              children: [
                _webDetail(isDark, Icons.person_outline_rounded, 'Full name',
                    _profile.fullName),
                _webDetail(isDark, Icons.tag_rounded, 'Employee code',
                    _profile.employeeCode),
                _webDetail(
                  isDark,
                  Icons.alternate_email_rounded,
                  'Username',
                  _profile.username == null ? null : '@${_profile.username}',
                ),
                _webDetail(isDark, _roleIcon(_profile.role), 'Role',
                    _profile.role.toUpperCase()),
              ],
            ),
    );
  }

  Widget _buildWebContactCard(bool isDark, Color rc) {
    return WebCard(
      title: 'Contact',
      subtitle: 'Used for account notices and receipts',
      icon: Icons.contact_phone_outlined,
      child: _isEditing
          ? WebResponsiveRow(
              minChildWidth: 240,
              spacing: WebSpace.lg,
              children: [
                _buildField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  nextFocus: _emailFocus,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  isDark: isDark,
                  rc: rc,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    return digits.length != 10
                        ? 'Enter a valid 10-digit number'
                        : null;
                  },
                ),
                _buildField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  isDark: isDark,
                  rc: rc,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _saveProfile(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final emailRx = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
                    return emailRx.hasMatch(v.trim())
                        ? null
                        : 'Enter a valid email';
                  },
                ),
              ],
            )
          : WebResponsiveRow(
              minChildWidth: 220,
              spacing: WebSpace.md,
              children: [
                _webDetail(isDark, Icons.phone_outlined, 'Phone', _profile.phone),
                _webDetail(isDark, Icons.email_outlined, 'Email', _profile.email),
              ],
            ),
    );
  }

  Widget _buildWebPermissionsCard(bool isDark) {
    final p = _permissions;
    final groups = p == null
        ? const <(String, IconData, List<_PermItem>)>[]
        : [
            (
              'Billing',
              Icons.receipt_long_outlined,
              [
                _PermItem('Create bill', p.canCreateBill),
                _PermItem('Edit bill', p.canEditBill),
                _PermItem('Cancel bill', p.canCancelBill),
                _PermItem('Apply discount', p.canApplyDiscount),
                _PermItem('Void items', p.canVoidItems),
              ],
            ),
            (
              'Access',
              Icons.key_outlined,
              [
                _PermItem('View dashboard', p.canViewDashboard),
                _PermItem('Manage tables', p.canManageTables),
                _PermItem('View reports', p.canViewReports),
                _PermItem('Manage items', p.canManageItems),
              ],
            ),
            (
              'Administration',
              Icons.admin_panel_settings_outlined,
              [
                _PermItem('Manage users', p.canManageUsers),
                _PermItem('Manage settings', p.canManageSettings),
                _PermItem('Manage stock', p.canManageStock),
              ],
            ),
          ];
    final all = [for (final g in groups) ...g.$3];
    final on = all.where((i) => i.enabled).length;

    return WebCard(
      title: 'Access & permissions',
      subtitle: 'Set by your administrator',
      icon: Icons.shield_outlined,
      trailing: [
        if (p == null && _isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            tooltip: 'Reload permissions',
            onPressed: _loadPermissions,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
      ],
      child: p == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: WebSpace.xl),
              child: Center(
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _loadPermissions,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Load permissions'),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '$on of ${all.length} enabled',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: WebPalette.text(isDark),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${all.isEmpty ? 0 : (on / all.length * 100).round()}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: WebPalette.muted(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: WebSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: all.isEmpty ? 0 : on / all.length,
                    minHeight: 6,
                    color: AppColors.tableFree,
                    backgroundColor: WebPalette.subtle(isDark),
                  ),
                ),
                for (final (label, icon, items) in groups) ...[
                  const SizedBox(height: WebSpace.lg),
                  Row(
                    children: [
                      Icon(icon, size: 16, color: WebPalette.muted(isDark)),
                      const SizedBox(width: WebSpace.sm),
                      Text(
                        label.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: WebPalette.muted(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WebSpace.xs),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Icon(
                            item.enabled
                                ? Icons.check_circle_rounded
                                : Icons.cancel_outlined,
                            size: 18,
                            color: item.enabled
                                ? AppColors.tableFree
                                : WebPalette.muted(isDark),
                          ),
                          const SizedBox(width: WebSpace.sm + 2),
                          Expanded(
                            child: Text(
                              item.label,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: item.enabled
                                    ? WebPalette.text(isDark)
                                    : WebPalette.muted(isDark),
                              ),
                            ),
                          ),
                          Text(
                            item.enabled ? 'Allowed' : 'No access',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: item.enabled
                                  ? AppColors.tableFree
                                  : WebPalette.muted(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark, Color rc) {
    final hasImage = _pickedImage != null;
    final hasAvatar =
        _profile.avatarUrl != null && _profile.avatarUrl!.isNotEmpty;
    final initials = _profile.fullName.isNotEmpty
        ? _profile.fullName
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0] : '')
              .join()
              .toUpperCase()
        : '?';

    return SizedBox(
      height: 260,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    rc.withValues(alpha: isDark ? 0.28 : 0.18),
                    rc.withValues(alpha: isDark ? 0.10 : 0.06),
                    (isDark ? AppColors.darkBg : AppColors.lightBg).withValues(
                      alpha: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rc.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rc.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 60,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rc.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rc.withValues(alpha: 0.15), width: 2),
              ),
            ),
          ),
          // AppBar row
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // Web opens this as a shell destination: no back button,
                    // the breadcrumbs cover it.
                    if (WebLayout.enabled)
                      const SizedBox(width: WebTokens.gap * 2)
                    else
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark
                              ? AppColors.textWhite
                              : AppColors.textDark,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    Expanded(
                      child: Text(
                        'My Profile',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textWhite
                              : AppColors.textDark,
                        ),
                      ),
                    ),
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: rc,
                          ),
                        ),
                      )
                    else if (_isEditing) ...[
                      TextButton(
                        onPressed: _cancelEdit,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            color: isDark
                                ? AppColors.textWhiteMuted
                                : AppColors.textDarkMuted,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saveProfile,
                        child: Text(
                          'Save',
                          style: GoogleFonts.inter(
                            color: rc,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ] else
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: isDark
                              ? AppColors.textWhiteMuted
                              : AppColors.textDarkMuted,
                        ),
                        onPressed: _startEdit,
                        tooltip: 'Edit Profile',
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Avatar + name block (centered)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Halo ring + avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: rc.withValues(alpha: 0.25),
                          width: 3,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isEditing ? _pickImage : null,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: rc, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: rc.withValues(alpha: 0.3),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: hasImage
                              ? Image.memory(
                                  _pickedImageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : hasAvatar
                              ? Image.network(
                                  _profile.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _avatarFallback(rc, initials),
                                )
                              : _avatarFallback(rc, initials),
                        ),
                      ),
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: rc,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBg
                                  : AppColors.lightBg,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Name
                Text(
                  _profile.fullName,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textWhite : AppColors.textDark,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 6),
                // Role chip + status
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: rc.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: rc.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_roleIcon(_profile.role), size: 13, color: rc),
                          const SizedBox(width: 4),
                          Text(
                            _profile.role.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: rc,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _profile.isActive
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _profile.isActive
                              ? AppColors.success.withValues(alpha: 0.4)
                              : AppColors.error.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _profile.isActive ? 'Active' : 'Inactive',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _profile.isActive
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(Color rc, String initials) {
    return Container(
      color: rc.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: rc,
          ),
        ),
      ),
    );
  }

  // ─── View mode ─────────────────────────────────────────────────────────────

  Widget _buildViewBody(bool isDark, Color rc) {
    return ListView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      children: [
        _ProfileCard(
          isDark: isDark,
          accentColor: rc,
          title: 'Personal Info',
          icon: Icons.badge_outlined,
          children: [
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Full Name',
              value: _profile.fullName,
              isDark: isDark,
            ),
            _InfoRow(
              icon: Icons.tag_rounded,
              label: 'Employee Code',
              value: _profile.employeeCode,
              isDark: isDark,
            ),
            if (_profile.username != null && _profile.username!.isNotEmpty)
              _InfoRow(
                icon: Icons.alternate_email_rounded,
                label: 'Username',
                value: '@${_profile.username}',
                isDark: isDark,
              ),
            if (_profile.createdAt != null)
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Member Since',
                value: _formatDate(_profile.createdAt!),
                isDark: isDark,
              ),
            if (_profile.lastLogin != null)
              _InfoRow(
                icon: Icons.login_rounded,
                label: 'Last Login',
                value: _formatDateTime(_profile.lastLogin!),
                isDark: isDark,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ProfileCard(
          isDark: isDark,
          accentColor: AppColors.info,
          title: 'Contact Info',
          icon: Icons.contact_phone_outlined,
          children: [
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: _profile.phone?.isNotEmpty == true
                  ? _profile.phone!
                  : 'Not set',
              isDark: isDark,
              muted: _profile.phone?.isNotEmpty != true,
            ),
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _profile.email?.isNotEmpty == true
                  ? _profile.email!
                  : 'Not set',
              isDark: isDark,
              muted: _profile.email?.isNotEmpty != true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPermissionsCard(isDark, rc),
      ],
    );
  }

  String _formatDate(DateTime dt) {
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
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

  Widget _buildPermissionsCard(bool isDark, Color rc) {
    return _ProfileCard(
      isDark: isDark,
      accentColor: const Color(0xFF7B1FA2),
      title: 'Permissions',
      icon: Icons.shield_outlined,
      trailing: _isLoading && _permissions == null
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: rc),
            )
          : null,
      children: [
        if (_permissions == null && !_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: TextButton.icon(
                onPressed: _loadPermissions,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  'Load permissions',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ),
          )
        else if (_permissions != null) ...[
          _PermGroup(
            label: 'Billing',
            color: AppColors.warning,
            isDark: isDark,
            perms: [
              _PermItem('Create Bill', _permissions!.canCreateBill),
              _PermItem('Edit Bill', _permissions!.canEditBill),
              _PermItem('Cancel Bill', _permissions!.canCancelBill),
              _PermItem('Apply Discount', _permissions!.canApplyDiscount),
              _PermItem('Void Items', _permissions!.canVoidItems),
            ],
          ),
          const SizedBox(height: 12),
          _PermGroup(
            label: 'Access',
            color: AppColors.info,
            isDark: isDark,
            perms: [
              _PermItem('View Dashboard', _permissions!.canViewDashboard),
              _PermItem('Manage Tables', _permissions!.canManageTables),
              _PermItem('View Reports', _permissions!.canViewReports),
              _PermItem('Manage Items', _permissions!.canManageItems),
            ],
          ),
          const SizedBox(height: 12),
          _PermGroup(
            label: 'Administration',
            color: const Color(0xFF5C6BC0),
            isDark: isDark,
            perms: [
              _PermItem('Manage Users', _permissions!.canManageUsers),
              _PermItem('Manage Settings', _permissions!.canManageSettings),
              _PermItem('Manage Stock', _permissions!.canManageStock),
            ],
          ),
        ] else
          const SizedBox(height: 8),
      ],
    );
  }

  // ─── Edit form ─────────────────────────────────────────────────────────────

  Widget _buildEditForm(bool isDark, Color rc) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        children: [
          _ProfileCard(
            isDark: isDark,
            accentColor: rc,
            title: 'Edit Info',
            icon: Icons.edit_outlined,
            children: [
              const SizedBox(height: 4),
              _buildField(
                controller: _nameController,
                focusNode: _nameFocus,
                nextFocus: _phoneFocus,
                label: 'Full Name',
                icon: Icons.person_outline_rounded,
                isDark: isDark,
                rc: rc,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                nextFocus: _emailFocus,
                label: 'Phone',
                icon: Icons.phone_outlined,
                isDark: isDark,
                rc: rc,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final digits = v.replaceAll(RegExp(r'\D'), '');
                  if (digits.length != 10)
                    return 'Enter a valid 10-digit number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _emailController,
                focusNode: _emailFocus,
                label: 'Email',
                icon: Icons.email_outlined,
                isDark: isDark,
                rc: rc,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveProfile(),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final emailRx = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
                  if (!emailRx.hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
          const SizedBox(height: 16),
          // Read-only info
          _ProfileCard(
            isDark: isDark,
            accentColor: AppColors.textDarkMuted,
            title: 'Read-Only Info',
            icon: Icons.lock_outline_rounded,
            children: [
              _InfoRow(
                icon: Icons.tag_rounded,
                label: 'Employee Code',
                value: _profile.employeeCode,
                isDark: isDark,
                muted: true,
              ),
              if (_profile.username != null && _profile.username!.isNotEmpty)
                _InfoRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'Username',
                  value: '@${_profile.username}',
                  isDark: isDark,
                  muted: true,
                ),
              _InfoRow(
                icon: _roleIcon(_profile.role),
                label: 'Role',
                value: _profile.role.toUpperCase(),
                isDark: isDark,
                muted: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Save button
          SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [rc, rc.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: rc.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.save_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                  label: Text(
                    _isLoading ? 'Saving…' : 'Save Changes',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color rc,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted:
          onFieldSubmitted ??
          (_) {
            if (nextFocus != null)
              FocusScope.of(context).requestFocus(nextFocus);
          },
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: isDark ? AppColors.textWhite : AppColors.textDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted,
        ),
        prefixIcon: Icon(icon, size: 18, color: rc.withValues(alpha: 0.75)),
        filled: true,
        fillColor: isDark
            ? AppColors.darkElevated.withValues(alpha: 0.5)
            : AppColors.lightElevated.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: rc, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final bool isDark;
  final Color accentColor;
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  const _ProfileCard({
    required this.isDark,
    required this.accentColor,
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: accentColor, width: 3),
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: accentColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textWhite : AppColors.textDark,
                    letterSpacing: 0.2,
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool muted;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark
        ? AppColors.textWhiteMuted
        : AppColors.textDarkMuted;
    final valueColor = muted
        ? labelColor
        : (isDark ? AppColors.textWhite : AppColors.textDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: labelColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: valueColor,
                    fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermItem {
  final String label;
  final bool enabled;
  const _PermItem(this.label, this.enabled);
}

class _PermGroup extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final List<_PermItem> perms;

  const _PermGroup({
    required this.label,
    required this.color,
    required this.isDark,
    required this.perms,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: perms.map((p) => _permChip(p)).toList(),
        ),
      ],
    );
  }

  Widget _permChip(_PermItem p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.enabled
            ? color.withValues(alpha: 0.12)
            : (isDark
                  ? AppColors.darkElevated.withValues(alpha: 0.5)
                  : AppColors.lightBg),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: p.enabled
              ? color.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            p.enabled
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 12,
            color: p.enabled
                ? color
                : (isDark ? AppColors.textWhiteMuted : AppColors.textDarkMuted),
          ),
          const SizedBox(width: 5),
          Text(
            p.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: p.enabled ? FontWeight.w600 : FontWeight.w400,
              color: p.enabled
                  ? color
                  : (isDark
                        ? AppColors.textWhiteMuted
                        : AppColors.textDarkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
