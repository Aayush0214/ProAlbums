import 'package:fpdart/fpdart.dart';
import 'package:proalbums/core/error/failures.dart';
import 'package:proalbums/core/utils/typedefs.dart';
import 'package:proalbums/features/gallery/domain/entities/media_item.dart';
import 'package:proalbums/features/gallery/domain/repositories/media_clipboard_repository.dart';

/// "Copy to clipboard" for the chosen pictures. Only pictures can be copied:
/// a selection with a video is refused (the menu greys the option out, this
/// is the safety net).
final class CopyToClipboardUseCase {
  const CopyToClipboardUseCase(this._repository);

  final MediaClipboardRepository _repository;

  /// true = the system showed its own "Copied" confirmation.
  FutureResult<bool> call(List<MediaItem> items) async {
    if (items.isEmpty || items.any((item) => item.isVideo)) {
      return left<Failure, bool>(
        const MediaFailure('Only pictures can be copied.'),
      );
    }
    return _repository.copyImages([for (final item in items) item.id]);
  }
}
