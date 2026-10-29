/// Which kind of media a query is about.
enum MediaKind { all, images, videos }

/// "Browsing order" from the Photos menu.
enum MediaSortOrder { newestFirst, oldestFirst }

/// Parameters of [GetMediaPage]. Page numbers start at 0.
final class MediaPageRequest {
  const MediaPageRequest({
    required this.page,
    this.pageSize = 100,
    this.kind = MediaKind.all,
    this.order = MediaSortOrder.newestFirst,
  });

  final int page;
  final int pageSize;
  final MediaKind kind;
  final MediaSortOrder order;
}
