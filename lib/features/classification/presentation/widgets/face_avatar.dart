import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proalbums/core/theme/app_colors.dart';
import 'package:proalbums/features/classification/data/face_repository.dart';
import 'package:proalbums/features/gallery/presentation/images/media_thumbnail_image.dart';
import 'package:proalbums/features/gallery/presentation/widgets/media_thumbnail.dart';

/// A face in a circle, cut from its picture's normal thumbnail (same
/// cache as the grids): the face in the middle, with some hair and chin
/// around it.
class FaceAvatar extends ConsumerStatefulWidget {
  const FaceAvatar({required this.face, required this.diameter, super.key});

  final StoredFace face;
  final double diameter;

  @override
  ConsumerState<FaceAvatar> createState() => _FaceAvatarState();
}

class _FaceAvatarState extends ConsumerState<FaceAvatar> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener(_onImage);

  /// Thumbnail size (short side): a small face needs a bigger picture to
  /// stay sharp in the circle.
  int _sizeFor(double devicePixelRatio) {
    final faceShare = (widget.face.right - widget.face.left).clamp(0.05, 1.0);
    final needed =
        widget.diameter * devicePixelRatio / (faceShare * _FacePainter.zoom);
    return needed <= 512 ? 512 : 1024;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(FaceAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.face.mediaId != widget.face.mediaId ||
        oldWidget.diameter != widget.diameter) {
      _resolve();
    }
  }

  void _resolve() {
    final provider = MediaThumbnailImage(
      id: widget.face.mediaId,
      size: _sizeFor(MediaQuery.devicePixelRatioOf(context)),
      load: thumbnailLoader(ref),
    );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _info?.image;
    return SizedBox.square(
      dimension: widget.diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: context.colorScheme.outlineVariant,
            width: 0.8,
          ),
        ),
        child: ClipOval(
          child: image == null
              ? const SizedBox.expand()
              : CustomPaint(
                  painter: _FacePainter(image, widget.face),
                  size: Size.square(widget.diameter),
                ),
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.image, this.face);

  final ui.Image image;
  final StoredFace face;

  /// The circle shows this many times the face box: the face with its
  /// hair, little of the people around (like the system gallery).
  static const double zoom = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final faceW = (face.right - face.left) * w;
    final faceH = (face.bottom - face.top) * h;
    final side = math.min(math.max(faceW, faceH) * zoom, math.min(w, h));
    final cx = (face.left + face.right) / 2 * w;
    // A little up: the box starts at the eyebrows, the hair is above.
    final cy = (face.top + face.bottom) / 2 * h - faceH * 0.08;
    final left = (cx - side / 2).clamp(0.0, w - side);
    final top = (cy - side / 2).clamp(0.0, h - side);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(left, top, side, side),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.image != image || old.face != face;
}
