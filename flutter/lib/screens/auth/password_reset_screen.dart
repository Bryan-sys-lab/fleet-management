import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';
import '../../data/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/field.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Two-step reset: request (returns reset_id + requires_approval) → complete.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _contact = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  String? _resetId;
  String? _error;
  bool _busy = false;

  Future<void> _request() async {
    final strings = context.s;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(repositoryProvider).passwordResetRequest(_contact.text.trim());
      setState(() => _resetId = result['reset_id'] as String?);
      if (_resetId == null) {
        setState(() => _error = strings.t('auth.passwordResetHelp'));
      }
    } on HelixError catch (e) {
      if (!mounted) return;
      setState(() => _error = strings.error(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).passwordResetComplete(_resetId!, _code.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on HelixError catch (e) {
      if (!mounted) return;
      setState(() => _error = context.s.error(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final requesting = _resetId == null;
    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('auth.passwordReset'), style: TypeScale.title(AppColors.text))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HelixText(
                requesting ? strings.t('auth.passwordResetHelp') : strings.t('auth.passwordResetCode'),
                style: TypeScale.body(AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpace.s5),
              if (requesting)
                Field(label: strings.t('auth.emailOrPhone'), controller: _contact)
              else ...[
                Field(label: strings.t('auth.mfaCode'), controller: _code),
                const SizedBox(height: AppSpace.s4),
                Field(label: strings.t('auth.password'), controller: _password, obscureText: true),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpace.s4),
                HelixText(_error!, style: TypeScale.body(AppColors.statusDanger)),
              ],
              const Spacer(),
              StrandButton(
                label: requesting ? strings.t('actions.CONTINUE') : strings.t('auth.passwordResetDone'),
                shell: Shell.driver,
                onPressed: _busy ? null : (requesting ? _request : _complete),
                busy: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
