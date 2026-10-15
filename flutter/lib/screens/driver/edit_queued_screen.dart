import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/container.dart';
import '../../core/offline/queue_store.dart';
import '../../design/components/buttons.dart';
import '../../design/components/field.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Editor for a FAILED_REVIEW row: flattens the body to `path › key` fields.
/// Saving assigns a NEW idempotency key, then drains.
class EditQueuedScreen extends ConsumerStatefulWidget {
  const EditQueuedScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<EditQueuedScreen> createState() => _EditQueuedScreenState();
}

class _EditQueuedScreenState extends ConsumerState<EditQueuedScreen> {
  final _controllers = <String, TextEditingController>{};
  final _keys = <String>[];
  QueueItem? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final item = await ref.read(containerProvider).queue.itemById(widget.id);
    if (item == null) return;
    _item = item;
    item.body.forEach((key, value) {
      if (value is String) {
        _keys.add(key);
        _controllers[key] = TextEditingController(text: value);
      }
    });
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final queue = ref.read(containerProvider).queue;
    final body = Map<String, dynamic>.of(_item!.body);
    for (final key in _keys) {
      body[key] = _controllers[key]!.text.trim();
    }
    await queue.edit(widget.id, body);
    await queue.drain();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingBody());
    return Scaffold(
      appBar: AppBar(title: HelixText(_item?.path ?? 'Edit', style: TypeScale.title(AppColors.text))),
      body: Screen(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final key in _keys) ...[
              Field(label: key, controller: _controllers[key]),
              const SizedBox(height: AppSpace.s4),
            ],
            const SizedBox(height: AppSpace.s4),
            StrandButton(label: context.s.t('actions.save'), shell: Shell.driver, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
