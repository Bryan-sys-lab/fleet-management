import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';
import '../../data/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/card.dart';
import '../../design/components/field.dart';
import '../../design/components/privacy_shield.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// MFA enrolment: password confirm → recovery codes shown ONCE. Screenshot
/// blocked, codes not selectable — the delivered OTP model, no TOTP.
class MfaSetupScreen extends ConsumerStatefulWidget {
  const MfaSetupScreen({super.key});

  @override
  ConsumerState<MfaSetupScreen> createState() => _MfaSetupScreenState();
}

class _MfaSetupScreenState extends ConsumerState<MfaSetupScreen> {
  final _password = TextEditingController();
  List<String>? _codes;
  bool _busy = false;

  Future<void> _enroll() async {
    setState(() => _busy = true);
    try {
      final codes = await ref.read(repositoryProvider).mfaEnroll(_password.text);
      if (!mounted) return;
      setState(() => _codes = codes);
    } on HelixError catch (e) {
      if (!mounted) return;
      showHelixError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    return PrivacyShield(
      child: Scaffold(
        appBar: AppBar(title: HelixText(strings.t('mfa.title'), style: TypeScale.title(AppColors.text))),
        body: Screen(
          child: _codes == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HelixText(strings.t('mfa.body'), style: TypeScale.body(AppColors.text)),
                    const SizedBox(height: AppSpace.s5),
                    Field(label: strings.t('mfa.password'), controller: _password, obscureText: true),
                    const SizedBox(height: AppSpace.s5),
                    StrandButton(
                      label: strings.t('mfa.start'),
                      shell: Shell.driver,
                      onPressed: _busy ? null : _enroll,
                      busy: _busy,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HelixText(strings.t('mfa.recoveryHelp'), style: TypeScale.body(AppColors.statusDanger)),
                    const SizedBox(height: AppSpace.s4),
                    HelixCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final code in _codes!)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
                              child: HelixText(code, style: TypeScale.mono(AppColors.text)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    HelixText(strings.t('mfa.deliveredCodeHelp'), style: TypeScale.caption(AppColors.textSecondary)),
                  ],
                ),
        ),
      ),
    );
  }
}
