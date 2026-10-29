/// Parameters of [GetMediaThumbnail]. [size] is the square side in pixels.
final class ThumbnailRequest {
  const ThumbnailRequest({required this.id, required this.size});

  final String id;
  final int size;
}
