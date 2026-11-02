import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/app/router/app_routes.dart';
import 'package:proalbums/features/albums/domain/entities/album.dart';

/// Opens one album (full screen, over the bottom navigation bar).
void openAlbum(BuildContext context, Album album) {
  unawaited(context.push<void>(AppRoutes.album(album.id, album.name)));
}
