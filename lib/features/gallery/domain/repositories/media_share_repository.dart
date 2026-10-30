import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/utils/typedefs.dart';

/// Sends photos/videos to other apps (WhatsApp, Gmail...) through the
/// system share sheet.
abstract interface class MediaShareRepository {
  /// [ids] are media ids, in the order they should be shared.
  FutureResult<Unit> shareMedia(List<String> ids);
}
