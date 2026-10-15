import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../design/components/buttons.dart';
import '../../design/components/field.dart';
import '../../design/components/privacy_shield.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

class MfaScreen extends ConsumerStatefulWidget {
  const MfaScreen({super.key});

  @override
  ConsumerState<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends ConsumerState<MfaScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    final strings = context.s;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider).verifyMfa(_code.text.trim());
    } on HelixError catch (e) {
      if (!mounted) return;
      setState(() => _error = strings.error(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    return PrivacyShield(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HelixText(strings.t('auth.mfaCode'), style: TypeScale.title(AppColors.text)),
                const SizedBox(height: AppSpace.s2),
                HelixText(strings.t('auth.mfaHelp'), style: TypeScale.body(AppColors.textSecondary)),
                const SizedBox(height: AppSpace.s5),
                Field(
                  label: strings.t('auth.mfaCode'),
                  controller: _code,
                  keyboardType: TextInputType.text,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.s4),
                  HelixText(_error!, style: TypeScale.body(AppColors.statusDanger)),
                ],
                const SizedBox(height: AppSpace.s5),
                StrandButton(
                  label: strings.t('auth.verify'),
                  shell: Shell.driver,
                  onPressed: _busy ? null : _submit,
                  busy: _busy,
                ),
                const SizedBox(height: AppSpace.s3),
                QuietButton(
                  label: strings.t('auth.logOut'),
                  onPressed: () => ref.read(sessionProvider).signOut(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
