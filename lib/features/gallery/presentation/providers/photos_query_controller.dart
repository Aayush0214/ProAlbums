import 'package:flutter/foundation.dart';
import 'package:proalbums/features/gallery/domain/entities/media_page_request.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photos_query_controller.g.dart';

/// WHAT the Photos tab loads: which kind of media. Changing it reloads the
/// list. (The browsing order is NOT part of it: the data is always loaded
/// newest first and only DISPLAYED the other way round, so flipping the order
/// costs nothing. See PhotosViewSettings.)
@immutable
final class PhotosQuery {
  const PhotosQuery({this.kind = MediaKind.all});

  final MediaKind kind;

  PhotosQuery copyWith({MediaKind? kind}) =>
      PhotosQuery(kind: kind ?? this.kind);

  @override
  bool operator ==(Object other) => other is PhotosQuery && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

@Riverpod(keepAlive: true)
class PhotosQueryController extends _$PhotosQueryController {
  @override
  PhotosQuery build() => const PhotosQuery();

  void setKind(MediaKind kind) => state = state.copyWith(kind: kind);
}
