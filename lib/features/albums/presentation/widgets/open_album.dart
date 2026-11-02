import 'package:flutter/material.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';
import 'package:proalbums/features/albums/presentation/pages/album_detail_page.dart';

/// Opens one album (full screen, over the bottom navigation bar).
void openAlbum(BuildContext context, Album album) {
  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (context) =>
          AlbumDetailPage(albumId: album.id, title: album.name),
    ),
  );
}
