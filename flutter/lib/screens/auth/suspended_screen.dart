import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HelixText(strings.t('auth.suspendedTitle'), style: TypeScale.title(AppColors.statusDanger)),
              const SizedBox(height: AppSpace.s3),
              HelixText(strings.t('auth.suspended'), style: TypeScale.body(AppColors.text)),
              const SizedBox(height: AppSpace.s5),
              QuietButton(label: strings.t('auth.logOut'), onPressed: () => ref.read(sessionProvider).signOut()),
            ],
          ),
        ),
      ),
    );
  }
}
