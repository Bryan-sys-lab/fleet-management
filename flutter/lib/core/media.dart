import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'api_client.dart';
import 'policy.dart';
import 'ids.dart';
import 'offline/queue_store.dart';

/// Media pipeline: resize to the policy budget, compress to fit, stage to app
/// storage, presign (re-issued per attempt) → raw PUT → media_object_id.
class MediaService {
  // ignore: prefer_initializing_formals
  MediaService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  // owner_kind values used by the app's captures
  static const ownerWorkLog = 'WORK_LOG_PHOTO';
  static const ownerFuelReceipt = 'FUEL_RECEIPT';
  static const ownerFuelOdometer = 'FUEL_DASHBOARD';
  static const ownerAccident = 'ACCIDENT_MEDIA';
  static const ownerInspection = 'INSPECTION_ITEM';
  static const ownerTrailer = 'TRAILER_SWAP';
  static const ownerIssue = 'VEHICLE_ISSUE';
  static const ownerFuelPurchase = 'FUEL_PURCHASE';

  // retention_class values
  static const retentionReceipt = 'RECEIPT';
  static const retentionInspection = 'INSPECTION';
  static const retentionAccident = 'ACCIDENT';
  static const retentionWorkPlan = 'WORK_PLAN';
  static const retentionStatement = 'STATEMENT_IMPORT';

  /// Compresses [bytes] to the device-side budget (1080px / 500KB, B-07) and
  /// returns the encoded JPEG, or null when it cannot fit.
  static Future<Uint8List?> fitBudget(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    var image = decoded;
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > Policy.mediaMaxWidthPx) {
      final scale = Policy.mediaMaxWidthPx / longest;
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }
    for (final quality in [70, 50, 35, 20]) {
      final out = img.encodeJpg(image, quality: quality);
      if (out.length <= Policy.mediaMaxBytes) return out;
    }
    final last = img.encodeJpg(image, quality: 20);
    return last.length <= Policy.mediaMaxBytes ? last : null;
  }

  /// Stages a capture for the given slot (e.g. `media://receipt`).
  Future<StagedUpload?> stageCapture(
    Uint8List bytes, {
    required String slot,
    required String ownerKind,
    String retentionClass = retentionReceipt,
  }) async {
    final fitted = await fitBudget(bytes);
    if (fitted == null) return null; // UPLOAD_UNAVAILABLE — caller shows the state
    final dir = await stagingDir();
    final file = File('${dir.path}/${newUuid()}.jpg');
    await file.writeAsBytes(fitted);
    return StagedUpload(
      slot: slot,
      stagedPath: file.path,
      contentType: 'image/jpeg',
      ownerKind: ownerKind,
      retentionClass: retentionClass,
    );
  }

  /// Presign → PUT, returning the media object id. Called per attempt.
  Future<String> uploadStaged(StagedUpload upload) async {
    final response = await _api.write<Map<String, dynamic>>(
      'POST',
      'media/upload-url',
      body: {
        'owner_kind': upload.ownerKind,
        'retention_class': upload.retentionClass,
        'content_type': upload.contentType,
        if (upload.widthPx != null) 'width_px': upload.widthPx,
        if (upload.heightPx != null) 'height_px': upload.heightPx,
      },
      idempotent: false, // the contract deliberately omits the header here
      parse: (b) => b as Map<String, dynamic>,
    );
    final mediaObjectId = response['mediaObjectId'] as String; // camelCase route
    final uploadUrl = response['uploadUrl'] as String;
    final bytes = await File(upload.stagedPath).readAsBytes();
    await _api.putBytes(uploadUrl, bytes, upload.contentType);
    return mediaObjectId;
  }

  // ── slot tokens used by the forms (substituted at send time) ──
  static const slotReceipt = 'media://receipt';
  static const slotGauge = 'media://gauge';
  static const slotClockIn = 'media://clock_in';
  static const slotClockOut = 'media://clock_out';
  static const slotHook = 'media://hook';
  static const slotAccidentFront = 'media://accident_front';
  static const slotAccidentRear = 'media://accident_rear';
  static const slotAccidentSide = 'media://accident_side';
  static const slotAccidentExtra = 'media://accident_extra';
  static const slotIssue = 'media://issue';
  static String defectSlot(String templateItemId) => 'media://defect_$templateItemId';
}
