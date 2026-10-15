import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../data/providers.dart';
import '../../design/components/paged_list.dart';
import '../../design/components/text.dart';
import '../../design/components/status_badge.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Training lessons + roster entry; complete is gated `training:complete`.
class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    final canComplete = ref.watch(sessionProvider).permissions.contains('training:complete');
    final canReview = ref.watch(sessionProvider).permissions.contains('training:review');
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('training.title'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
        actions: [
          if (canReview)
            TextButton(
              onPressed: () => context.push('/admin/training/roster'),
              child: HelixText(strings.t('training.roster'), style: TypeScale.button(AppColors.adminAccent)),
            ),
        ],
      ),
      body: PagedList<Map<String, dynamic>>(
        emptyMessage: strings.t('training.title'),
        loadMore: (cursor) async {
          try {
            return await ref.read(repositoryProvider).page('training/lessons', cursor: cursor);
          } on HelixError catch (e) {
            throw HelixErrorLike(strings.error(e.code), actionLabel: strings.actionLabel(e.catalogue.action.name));
          }
        },
        itemBuilder: (context, row) {
          final mandatory = row['is_mandatory'] == true;
          return ListTile(
            leading: mandatory ? const HelixChip(label: '!', color: AppColors.statusDanger) : null,
            title: HelixText(row['title']?.toString() ?? '', style: TypeScale.body(AppColors.text)),
            subtitle: HelixText(
              '${row['course_title'] ?? ''} · ${row['duration_minutes'] ?? 0} ${strings.t('training.minutes')}',
              style: TypeScale.caption(AppColors.textSecondary),
            ),
            trailing: canComplete
                ? OutlinedButton(
                    onPressed: () async {
                      try {
                        await ref.read(repositoryProvider).completeTraining(row['id'] as String);
                        if (context.mounted) ref.invalidate(_lessonsProvider);
                      } on HelixError catch (e) {
                        if (context.mounted) showHelixError(context, e);
                      }
                    },
                    child: HelixText(strings.t('training.complete'), style: TypeScale.button(AppColors.adminAccent)),
                  )
                : null,
          );
        },
      ),
    );
  }
}

final _lessonsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final page = await ref.watch(repositoryProvider).page('training/lessons');
  return page.data;
});
