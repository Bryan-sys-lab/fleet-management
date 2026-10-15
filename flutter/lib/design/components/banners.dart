import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/container.dart';
import '../tokens.dart';
import 'text.dart';

/// 4s bottom toast, announced to screen readers.
class ToastController extends ChangeNotifier {
  String? _message;
  String? get message => _message;
  int _nonce = 0;
  int get nonce => _nonce;

  void show(String message) {
    _message = message;
    _nonce += 1;
    notifyListeners();
  }

  void clear() {
    _message = null;
    notifyListeners();
  }
}

final toastProvider = ChangeNotifierProvider<ToastController>((ref) => ToastController());

class Toast extends ConsumerStatefulWidget {
  const Toast({super.key});

  @override
  ConsumerState<Toast> createState() => _ToastState();
}

class _ToastState extends ConsumerState<Toast> {
  @override
  Widget build(BuildContext context) {
    final toast = ref.watch(toastProvider);
    if (toast.message == null) return const SizedBox.shrink();
    return Positioned(
      left: AppSpace.s4,
      right: AppSpace.s4,
      bottom: AppSpace.s6 + kBottomNavigationBarHeight,
      child: Semantics(
        liveRegion: true,
        child: AnimatedOpacity(
          opacity: 1,
          duration: AppMotion.durFade,
          curve: AppMotion.easeOut,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s4),
            decoration: BoxDecoration(
              color: AppColors.surfaceInverse,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: HelixText(toast.message!, style: TypeScale.body(AppColors.textInverse)),
          ),
        ),
      ),
    );
  }
}

/// Honest offline banner — the field principle, always visible when offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final container = ref.watch(containerProvider);
    return StreamBuilder<bool>(
      stream: container.connectivity.changes,
      initialData: container.connectivity.isOnline,
      builder: (context, snapshot) {
        if (snapshot.data == true) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: AppColors.surfaceInverse,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2, horizontal: AppSpace.s4),
          child: SafeArea(
            bottom: false,
            child: HelixText(
              'You are offline. Changes are saved and will send when you reconnect.',
              style: TypeScale.caption(AppColors.textInverse),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
