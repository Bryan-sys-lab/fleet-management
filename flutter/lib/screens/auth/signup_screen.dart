import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../design/components/buttons.dart';
import '../../design/components/field.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Self-service company signup — creates the tenant + first ADMIN.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _company = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    final strings = context.s;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider).signup(
        companyName: _company.text.trim(),
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
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
    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('auth.signUp'), style: TypeScale.title(AppColors.text))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Field(label: strings.t('auth.companyName'), controller: _company, required: true),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('auth.fullName'), controller: _name, required: true),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('drivers.email'), controller: _email, required: true),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('auth.password'), controller: _password, obscureText: true, required: true),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.s4),
                HelixText(_error!, style: TypeScale.body(AppColors.statusDanger)),
              ],
              const Spacer(),
              StrandButton(
                label: strings.t('auth.signUp'),
                shell: Shell.driver,
                onPressed: _busy ? null : _submit,
                busy: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
