import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/config.dart';
import '../../core/session.dart';
import '../../core/errors.dart';
import '../../data/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/card.dart';
import '../../design/components/field.dart';
import '../../design/components/screen.dart';
import '../../design/components/sheet_host.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Driver settings: Account / Security / Profile / Device / Data groups, the
/// language toggle, and the SHELL SWITCHER for dual-role sessions.
class DriverSettingsScreen extends ConsumerWidget {
  const DriverSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    final session = ref.watch(sessionProvider);
    final locale = ref.watch(localeProvider);
    final hasAdmin = session.roles.any(adminRoles.contains);

    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('nav.more'), style: TypeScale.title(AppColors.text))),
      body: Screen(
        refresh: () async {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Section(
              title: strings.t('settings.account'),
              children: [
                ListTile(
                  title: HelixText(strings.t('profileExtra.name'), style: TypeScale.caption(AppColors.textSecondary)),
                  subtitle: HelixText(session.userId ?? '—', style: TypeScale.body(AppColors.text)),
                ),
                ListTile(
                  title: HelixText(strings.t('profile.language'), style: TypeScale.body(AppColors.text)),
                  trailing: HelixText(
                    locale.languageCode == 'sw' ? 'Kiswahili' : 'English',
                    style: TypeScale.bodyStrong(AppColors.accentText),
                  ),
                  onTap: () => ref.read(localeProvider.notifier).toggle(),
                ),
                if (hasAdmin)
                  ListTile(
                    leading: const Icon(Icons.swap_horiz, color: AppColors.adminAccent),
                    title: HelixText(
                      strings.t('settings.switchRole', {'role': strings.t('settings.roleADMIN')}),
                      style: TypeScale.body(AppColors.text),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () async {
                      await session.persistShell('admin');
                      if (!context.mounted) return;
                      context.go('/admin/overview');
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s5),
            Section(
              title: strings.t('settings.security'),
              children: [
                ListTile(
                  title: HelixText(strings.t('profile.resetPin'), style: TypeScale.body(AppColors.text)),
                  onTap: () => _setPin(context, ref),
                ),
                ListTile(
                  title: HelixText(strings.t('profile.setupMfa'), style: TypeScale.body(AppColors.text)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => context.push('/driver/mfa-setup'),
                ),
                ListTile(
                  title: HelixText(strings.t('settings.changePassword'), style: TypeScale.body(AppColors.text)),
                  onTap: () => _changePassword(context, ref),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s5),
            Section(
              title: strings.t('settings.device'),
              children: [
                ListTile(
                  title: HelixText(strings.t('profile.openOutbox'), style: TypeScale.body(AppColors.text)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => context.push('/driver/outbox'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s5),
            Section(
              title: strings.t('settings.data'),
              children: [
                ListTile(
                  title: HelixText(strings.t('profile.openOutbox'), style: TypeScale.body(AppColors.text)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () => context.push('/driver/outbox'),
                ),
                ListTile(
                  title: HelixText(strings.t('auth.logOut'), style: TypeScale.body(AppColors.statusDanger)),
                  onTap: () => ref.read(sessionProvider).signOut(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final pin = await SheetHost.show<String>(
      context: context,
      title: context.s.t('profile.resetPin'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: Field(label: context.s.t('pin.title'), controller: controller, keyboardType: TextInputType.number),
      ),
    );
    if (pin == null || pin.length != 4) return;
    await ref.read(sessionProvider).setPin(pin);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.s.t('profile.pinSaved'))));
    controller.dispose();
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    await SheetHost.show(
      context: context,
      title: context.s.t('settings.changePassword'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Field(label: context.s.t('auth.password'), controller: current, obscureText: true),
            const SizedBox(height: AppSpace.s4),
            Field(label: context.s.t('settings.newPassword'), controller: next, obscureText: true),
            const SizedBox(height: AppSpace.s4),
            StrandButton(
              label: context.s.t('actions.save'),
              shell: Shell.driver,
              onPressed: () async {
                try {
                  await ref.read(repositoryProvider).changePassword(current.text, next.text);
                  if (context.mounted) Navigator.of(context).pop();
                } on HelixError catch (e) {
                  if (context.mounted) showHelixError(context, e);
                }
              },
            ),
          ],
        ),
      ),
    );
    current.dispose();
    next.dispose();
  }
}

/// Consent reference shown in the Device group.
final consentVersionRef = Config.consentVersion;
