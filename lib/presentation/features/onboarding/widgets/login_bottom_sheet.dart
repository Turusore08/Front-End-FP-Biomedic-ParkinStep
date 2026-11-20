import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../di/onboarding_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';

/// Accessible account sign-in sheet triggered from S-01 `Masuk dengan Akun`.
/// Supports keyboard traversal, visible labels, >= 56 dp inputs/actions, and
/// non-color-only error states.
class LoginBottomSheet extends ConsumerStatefulWidget {
  const LoginBottomSheet({
    super.key,
    required this.onSuccess,
  });

  final VoidCallback onSuccess;

  @override
  ConsumerState<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends ConsumerState<LoginBottomSheet> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _localError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    final err =
        await ref.read(onboardingControllerProvider.notifier).signInWithAccount(
              identifier: _identifierController.text,
              password: _passwordController.text,
            );
    if (!mounted) return;
    if (err != null) {
      setState(() => _localError = err);
      return;
    }
    Navigator.of(context).pop();
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(
      onboardingControllerProvider.select((s) => s.isSubmitting),
    );
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.subtleBorderLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Masuk dengan Akun',
                  style: AppTypography.screenTitle(size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gunakan akun pasien atau caregiver agar ringkasan hasil dapat disinkronkan ke dokter saraf.',
                  style: AppTypography.bodyLarge(size: 14.5),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.iceSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.skyCard),
                  ),
                  child: Text(
                    'Catatan Build Pratinjau: server klinis belum ditautkan pada perangkat ini. Login berjalan sebagai sesi pratinjau lokal tervalidasi.',
                    style: AppTypography.captionBadge(
                      color: AppColors.onIceAzure,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Email atau Nomor HP',
                  style: AppTypography.captionBadge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('login_identifier_field'),
                  controller: _identifierController,
                  enabled: !isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: AppTypography.bodyLarge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'contoh@email.com atau 08123456789',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Kata Sandi',
                  style: AppTypography.captionBadge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('login_password_field'),
                  controller: _passwordController,
                  enabled: !isSubmitting,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: AppTypography.bodyLarge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Minimal 8 karakter',
                    suffixIcon: Semantics(
                      button: true,
                      label: _obscurePassword
                          ? 'Tampilkan kata sandi'
                          : 'Sembunyikan kata sandi',
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: TextButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          child: Text(
                            _obscurePassword ? 'Lihat' : 'Tutup',
                            style: AppTypography.captionBadge(
                              color: AppColors.onIceAzure,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_localError != null) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.redSoftBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.alertRed),
                      ),
                      child: Row(
                        children: [
                          ParkinIcons.alertTriangle(color: AppColors.redDarkText),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _localError!,
                              style: AppTypography.captionBadge(
                                color: AppColors.redDarkText,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ParkinPrimaryPillButton(
                  key: const Key('login_submit_button'),
                  label: 'Masuk & Lanjutkan',
                  leadingIcon: ParkinIcons.login(),
                  isLoading: isSubmitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Batal',
                      style: AppTypography.buttonLabel(
                        color: AppColors.mutedSlate,
                        size: 16.0,
                      ),
                    ),
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
