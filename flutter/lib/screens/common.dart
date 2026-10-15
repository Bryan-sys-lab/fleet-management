import 'package:flutter/material.dart';
import '../../design/components/skeleton.dart';
import '../../design/components/states.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../../core/errors.dart';
import '../../i18n/strings.dart';

/// Localised strings + the standard error surface for every screen.
extension ScreenX on BuildContext {
  Strings get s => Strings.of(this);
}

/// Catalogue message + exactly one action (mirrors the Expo ErrorState).
void showHelixError(BuildContext context, Object error, {VoidCallback? retry}) {
  final strings = context.s;
  final message = error is HelixError ? strings.error(error.code) : strings.error('UNKNOWN');
  if (retry != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: strings.t('actions.RETRY'), onPressed: retry),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Catalogue message + one action rendered inline (list-level failures).
Widget inlineError(BuildContext context, Object error, {VoidCallback? retry}) {
  final strings = context.s;
  final code = error is HelixError ? error.code : 'UNKNOWN';
  final catalogue = (error is HelixError ? error.catalogue : null);
  int? wait;
  if (error is HelixError && error.code == 'RATE_LIMITED') {
    wait = error.retryAfterSeconds ?? 15;
  }
  return ErrorState(
    message: strings.error(code),
    actionLabel: catalogue == null ? null : strings.actionLabel(catalogue.action.name),
    onAction: retry,
    waitSeconds: wait,
  );
}

class LoadingBody extends StatelessWidget {
  const LoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpace.s4),
      child: Column(
        children: [
          Skeleton(height: 44),
          SizedBox(height: AppSpace.s3),
          Skeleton(height: 44),
          SizedBox(height: AppSpace.s3),
          Skeleton(height: 44),
        ],
      ),
    );
  }
}

/// Standard screen header: display title + optional lead subtitle.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelixText(title, style: TypeScale.title(AppColors.text)),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.s1),
            HelixText(subtitle!, style: TypeScale.body(AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
