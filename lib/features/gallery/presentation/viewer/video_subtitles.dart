import 'package:video_player/video_player.dart';

/// Reads a subtitle file the person picked: SubRip (.srt) or WebVTT (.vtt).
/// null = not a subtitle file we can read, or no lines in it.
ClosedCaptionFile? parseSubtitleFile(String name, String text) {
  // Many files start with an invisible "byte order mark" and use Windows
  // line ends; the readers expect neither.
  final clean = text
      .replaceFirst('﻿', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final lower = name.toLowerCase();
  final ClosedCaptionFile file;
  if (lower.endsWith('.vtt') || clean.trimLeft().startsWith('WEBVTT')) {
    file = WebVTTCaptionFile(clean);
  } else if (lower.endsWith('.srt')) {
    file = SubRipCaptionFile(clean);
  } else {
    return null;
  }
  try {
    return file.captions.isEmpty ? null : file;
  } on Object {
    // A broken file.
    return null;
  }
}
