import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/config.dart';
import '../../design/components/buttons.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// GPS tracking consent. Accept continues; decline signs out (guard-carried).
class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HelixText(strings.t('auth.consentTitle'), style: TypeScale.title(AppColors.text)),
              const SizedBox(height: AppSpace.s3),
              HelixText(strings.t('consent.body'), style: TypeScale.body(AppColors.text)),
              const Spacer(),
              StrandButton(
                label: strings.t('auth.accept'),
                shell: Shell.driver,
                onPressed: () => ref.read(sessionProvider).acceptConsent(Config.consentVersion),
              ),
              const SizedBox(height: AppSpace.s3),
              QuietButton(
                label: strings.t('auth.decline'),
                onPressed: () => ref.read(sessionProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
