import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/breadcrumbs.dart';
import '../../../core/widgets/web_layout.dart';
import '../../../core/backend/backend.dart';
import '../../../core/utils/api_helper.dart';
import 'login_screen.dart'
    show AmbientBackground, FocusableTextField, ScaleButton;
import 'registration_otp_screen.dart';

/// Registration — collects company details AND first-admin credentials in one
/// form, submits to the backend, then hands off to the OTP screen.
/// After OTP is confirmed the admin account is created automatically and the
/// user is sent straight to the login screen.
class CompanyRegistrationScreen extends StatefulWidget {
  const CompanyRegistrationScreen({super.key});

  @override
  State<CompanyRegistrationScreen> createState() =>
      _CompanyRegistrationScreenState();
}

class _CompanyRegistrationScreenState
    extends State<CompanyRegistrationScreen> {
  // Company fields
  final _companyName = TextEditingController();
  final _companyCode = TextEditingController();
  // Admin fields
  final _adminName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminUsername = TextEditingController();
  final _adminPassword = TextEditingController();
  final _adminConfirm = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _companyName.dispose();
    _companyCode.dispose();
    _adminName.dispose();
    _adminEmail.dispose();
    _adminUsername.dispose();
    _adminPassword.dispose();
    _adminConfirm.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_companyName.text.trim().isEmpty) return 'Company name is required';
    if (_companyCode.text.trim().isEmpty) return 'Company code is required';
    if (_adminName.text.trim().isEmpty) return 'Admin full name is required';
    final email = _adminEmail.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      return 'A valid admin email is required';
    }
    if (_adminUsername.text.trim().isEmpty) return 'Username is required';
    if (_adminPassword.text.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (_adminPassword.text != _adminConfirm.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      AppFeedback.toast(context, err, isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await Backend.requestCompanyRegistration(
        company: {
          'company_name': _companyName.text.trim(),
          'company_code': _companyCode.text.trim(),
          'email': _adminEmail.text.trim(),
        },
        owner: {
          'owner_name': _adminName.text.trim(),
          'owner_email': _adminEmail.text.trim(),
        },
      );
      final registrationId = res['registration_id'] as String;
      final companyId = res['company_id'] as String;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'Verify OTP'),
          builder: (_) => RegistrationOtpScreen(
            registrationId: registrationId,
            companyId: companyId,
            companyName: _companyName.text.trim(),
            adminEmail: _adminEmail.text.trim(),
            adminData: {
              'user_name': _adminName.text.trim(),
              'employee_code': 'ADMIN001',
              'username': _adminUsername.text.trim(),
              'password': _adminPassword.text,
              'user_email': _adminEmail.text.trim(),
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AmbientBackground(
        child: Container(
          color: isDark
              ? Colors.black.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.4),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildForm(isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return Container(
      width: 480,
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.25)
              : AppColors.lightBorder.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (WebLayout.enabled) ...[
            Breadcrumbs(
              crumbs: [
                Crumb(
                  'Sign in',
                  icon: Icons.login_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Crumb('Register company'),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              if (!WebLayout.enabled) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  'Register your company',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textWhite : AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'A 6-digit OTP will be sent to the admin email for verification.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: isDark
                    ? AppColors.textWhiteMuted
                    : AppColors.textDarkMuted,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Company section ────────────────────────────────────
          _sectionLabel('Company Details', Icons.business_rounded, isDark),
          const SizedBox(height: 12),
          FocusableTextField(
            controller: _companyName,
            label: 'Company Name',
            prefixIcon: Icons.business_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          FocusableTextField(
            controller: _companyCode,
            label: 'Company Code',
            prefixIcon: Icons.tag_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 24),

          // ── Admin section ──────────────────────────────────────
          _sectionLabel('Admin Account', Icons.admin_panel_settings_rounded, isDark),
          const SizedBox(height: 12),
          FocusableTextField(
            controller: _adminName,
            label: 'Full Name',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          FocusableTextField(
            controller: _adminEmail,
            label: 'Admin Email',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          FocusableTextField(
            controller: _adminUsername,
            label: 'Username',
            prefixIcon: Icons.alternate_email_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          FocusableTextField(
            controller: _adminPassword,
            label: 'Password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 14),
          FocusableTextField(
            controller: _adminConfirm,
            label: 'Confirm Password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          const SizedBox(height: 28),
          ScaleButton(
            onTap: _submit,
            isLoading: _isLoading,
            child: Text(
              'Send OTP & Continue',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).moveY(begin: 12, end: 0);
  }

  Widget _sectionLabel(String title, IconData icon, bool isDark) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primaryAmber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: AppColors.primaryAmber),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryAmber,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Divider(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.4)
              : AppColors.lightBorder,
        ),
      ),
    ],
  );
}
