import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/device_info.dart';
import '../../core/errors.dart';
import '../../design/components/buttons.dart';
import '../../design/components/field.dart';
import '../../design/components/privacy_shield.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _contact = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;
  String? _deviceRegisterError;

  bool get _isPhone => RegExp(r'^\+?[1-9]\d{6,14}$').hasMatch(_contact.text.trim());

  Future<void> _submit() async {
    final strings = context.s;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(sessionProvider);
      final deviceIdHash = await DeviceInfo.deviceIdHash();
      final contact = _contact.text.trim();
      final result = await session.login(
        email: _isPhone ? null : contact,
        phone: _isPhone ? contact : null,
        password: _password.text,
        deviceIdHash: deviceIdHash,
      );
      // Register this device AFTER the session exists — never a gate.
      if (result != null) {
        await _registerDevice();
      }
    } on HelixError catch (e) {
      if (!mounted) return;
      setState(() => _error = strings.error(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registerDevice() async {
    final session = ref.read(sessionProvider);
    final deviceIdHash = await DeviceInfo.deviceIdHash();
    try {
      await session.registerDevice(
        deviceIdHash: deviceIdHash,
        label: await DeviceInfo.deviceLabel(),
        model: await DeviceInfo.deviceModel(),
        osVersion: await DeviceInfo.osVersion(),
        appVersion: await DeviceInfo.appVersion(),
      );
    } on HelixError catch (e) {
      if (!mounted) return;
      setState(() => _deviceRegisterError = e.code);
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
                const Spacer(),
                HelixText('Helix', style: TypeScale.display(AppColors.text)),
                const SizedBox(height: AppSpace.s2),
                HelixText(strings.t('auth.loginHelp'), style: TypeScale.body(AppColors.textSecondary)),
                const SizedBox(height: AppSpace.s6),
                Field(
                  label: strings.t('auth.emailOrPhone'),
                  controller: _contact,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpace.s4),
                Field(
                  label: strings.t('auth.password'),
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.s4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpace.s4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSunk,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.statusDanger),
                    ),
                    child: HelixText(_error!, style: TypeScale.body(AppColors.statusDanger)),
                  ),
                ],
                if (_deviceRegisterError != null) ...[
                  const SizedBox(height: AppSpace.s3),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: QuietButton(
                      label: '${strings.t('actions.REGISTER_DEVICE')} — ${strings.error(_deviceRegisterError!)}',
                      onPressed: _registerDevice,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.s5),
                StrandButton(
                  label: strings.t('auth.logIn'),
                  shell: Shell.driver,
                  onPressed: _busy ? null : _submit,
                  busy: _busy,
                ),
                const SizedBox(height: AppSpace.s3),
                Row(
                  children: [
                    QuietButton(
                      label: strings.t('auth.signUp'),
                      onPressed: () => context.push('/signup'),
                    ),
                    const Spacer(),
                    QuietButton(
                      label: strings.t('auth.forgotPassword'),
                      onPressed: () => context.push('/password-reset'),
                    ),
                  ],
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: AppSpace.s3),
                  QuietButton(
                    label: 'Design preview (offline)',
                    icon: const Icon(Icons.palette_outlined, size: 20, color: AppColors.adminAccent),
                    onPressed: () async {
                      await ref.read(sessionProvider).enterPreview();
                    },
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
