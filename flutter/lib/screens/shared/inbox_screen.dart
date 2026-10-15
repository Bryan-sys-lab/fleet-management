import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/deep_links.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../design/components/paged_list.dart';
import '../../design/components/segmented.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Inbox: Notifications / Flags / Documents. Mark-read only with
/// `notification:manage`; exact unread count drives the admin badge.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key, this.initial});

  final String? initial;

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  late String _segment = widget.initial ?? 'notifications';

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('inbox.title'), style: TypeScale.title(AppColors.text))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Segmented<String>(
              value: _segment,
              onChanged: (v) => setState(() => _segment = v),
              options: [
                SegmentedOption('notifications', strings.t('inbox.notifications')),
                SegmentedOption('flags', strings.t('inbox.flags')),
                SegmentedOption('docs', strings.t('inbox.docs')),
              ],
            ),
          ),
          Expanded(
            child: switch (_segment) {
              'notifications' => const _NotificationsList(),
              'flags' => const _FlagsList(),
              'docs' => const _DocsList(),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationsList extends ConsumerWidget {
  const _NotificationsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    final canManage = ref.watch(sessionProvider).permissions.contains('notification:manage');
    return PagedList<Map<String, dynamic>>(
      emptyMessage: strings.t('notifications.empty'),
      loadMore: (cursor) async {
        try {
          return await ref.read(repositoryProvider).page('notifications', cursor: cursor);
        } on HelixError catch (e) {
          throw HelixErrorLike(strings.error(e.code), actionLabel: strings.actionLabel(e.catalogue.action.name));
        }
      },
      itemBuilder: (context, row) {
        final unread = row['status'] == 'QUEUED' || row['status'] == 'SENT';
        final payload = row['payload'];
        final link = targetFromNotification(payload is Map<String, dynamic> ? payload : const {});
        return ListTile(
          leading: unread ? const Icon(Icons.circle, size: 10, color: AppColors.accentText) : null,
          title: HelixText(row['title']?.toString() ?? '', style: TypeScale.bodyStrong(AppColors.text)),
          subtitle: HelixText(
            '${row['body'] ?? ''} · ${Fmt.time(DateTime.tryParse(row['created_at']?.toString() ?? ''))}',
            style: TypeScale.caption(AppColors.textSecondary),
          ),
          onTap: () async {
            if (canManage) {
              try {
                await ref.read(repositoryProvider).markRead(row['id'] as String);
              } catch (_) {}
            }
            if (link != null && context.mounted) {
              context.go(routeForDeepLink(link, ref.read(sessionProvider)) ?? '/driver/inbox');
            }
          },
        );
      },
    );
  }
}

class _FlagsList extends ConsumerWidget {
  const _FlagsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    return PagedList<Map<String, dynamic>>(
      emptyMessage: strings.t('anomalies.empty'),
      loadMore: (cursor) async {
        try {
          return await ref.read(repositoryProvider).page('anomalies', cursor: cursor);
        } on HelixError catch (e) {
          throw HelixErrorLike(strings.error(e.code), actionLabel: strings.actionLabel(e.catalogue.action.name));
        }
      },
      itemBuilder: (context, row) => ListTile(
        title: HelixText(row['kind']?.toString() ?? '', style: TypeScale.body(AppColors.text)),
        subtitle: HelixText(
          '${row['domain'] ?? ''} · ${row['severity'] ?? ''}',
          style: TypeScale.caption(AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () => context.push('/anomaly/${row['id']}'),
      ),
    );
  }
}

class _DocsList extends ConsumerWidget {
  const _DocsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    return PagedList<Map<String, dynamic>>(
      emptyMessage: strings.t('docs.empty'),
      loadMore: (cursor) async {
        try {
          return await ref
              .read(repositoryProvider)
              .page('documents/expiring', cursor: cursor, query: {'within_days': 30});
        } on HelixError catch (e) {
          throw HelixErrorLike(strings.error(e.code), actionLabel: strings.actionLabel(e.catalogue.action.name));
        }
      },
      itemBuilder: (context, row) {
        final days = row['days_remaining'] as int?;
        return ListTile(
          title: HelixText(row['subject_name']?.toString() ?? '', style: TypeScale.body(AppColors.text)),
          subtitle: HelixText(row['document_type']?.toString() ?? '', style: TypeScale.caption(AppColors.textSecondary)),
          trailing: HelixText(
            days == null ? '' : days <= 0 ? strings.t('docs.expired') : strings.t('docs.days', {'n': '$days'}),
            style: TypeScale.caption(days != null && days <= 7 ? AppColors.statusDanger : AppColors.textSecondary),
          ),
          onTap: () => context.push('/document/${row['document_id']}'),
        );
      },
    );
  }
}
