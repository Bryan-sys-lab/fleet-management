import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Device integrity block: reason copy + forced sign-out (auto on mount).
class BlockedScreen extends ConsumerStatefulWidget {
  const BlockedScreen({super.key});

  @override
  ConsumerState<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends ConsumerState<BlockedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(sessionProvider).signOut());
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final reason = ref.read(sessionProvider).securityReason;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HelixText(strings.t('security.blockedTitle'), style: TypeScale.title(AppColors.statusDanger)),
              const SizedBox(height: AppSpace.s3),
              HelixText(
                switch (reason) {
                  'rooted' => strings.t('security.rooted'),
                  'hooked' => strings.t('security.hooked'),
                  'pinningMissing' => strings.t('security.pinningMissing'),
                  _ => strings.t('security.blockedBody'),
                },
                style: TypeScale.body(AppColors.text),
              ),
              const SizedBox(height: AppSpace.s5),
              QuietButton(
                label: strings.t('auth.logOut'),
                onPressed: () => ref.read(sessionProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
