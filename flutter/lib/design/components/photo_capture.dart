import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../tokens.dart';
import 'buttons.dart';
import 'text.dart';

/// Camera capture button → grant → camera view → captured bytes
/// (resize/compress happens in MediaService.stageCapture). No video mode (B-07).
class PhotoCapture extends StatefulWidget {
  const PhotoCapture({
    super.key,
    required this.cameras,
    required this.onCaptured,
    required this.label,
    this.captured,
  });

  final List<CameraDescription> cameras;
  final void Function(XFile file) onCaptured;
  final String label;
  final XFile? captured;

  @override
  State<PhotoCapture> createState() => _PhotoCaptureState();
}

class _PhotoCaptureState extends State<PhotoCapture> {
  CameraController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    final controller = CameraController(widget.cameras.first, ResolutionPreset.medium);
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final file = await controller.takePicture();
      widget.onCaptured(file);
      if (!mounted) return;
      setState(() => _ready = false);
      await controller.dispose();
      _controller = null;
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HelixText(widget.label, style: TypeScale.caption(AppColors.textSecondary)),
        const SizedBox(height: AppSpace.s2),
        if (!_ready)
          Container(
            height: AppTarget.touchPhone,
            decoration: BoxDecoration(
              color: AppColors.surfaceSunk,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: AppColors.line),
            ),
            child: QuietButton(
              label: _failed ? 'Camera unavailable' : 'Take photo',
              onPressed: _failed ? null : _openCamera,
              icon: const Icon(Icons.photo_camera_outlined, size: 20, color: AppColors.textSecondary),
            ),
          ),
        if (_ready && _controller != null)
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CameraPreview(_controller!),
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              StrandButton(label: 'Capture', shell: Shell.driver, onPressed: _shoot),
            ],
          ),
        if (widget.captured != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s2),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.statusOk, size: 18),
                const SizedBox(width: AppSpace.s2),
                HelixText('Captured', style: TypeScale.caption(AppColors.statusOk)),
              ],
            ),
          ),
      ],
    );
  }
}
