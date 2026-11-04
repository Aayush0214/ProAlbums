import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/presentation/viewer/video_player_page.dart';
import 'package:proalbums/features/gallery/presentation/viewer/video_subtitles.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('seekTargetFor', () {
    const short = Duration(seconds: 10);

    test('a short video: the screen width is the whole video', () {
      expect(
        seekTargetFor(from: Duration.zero, dx: 500, width: 1000, total: short),
        const Duration(seconds: 5),
      );
    });

    test('a long video: the width is at most 2 minutes', () {
      expect(
        seekTargetFor(
          from: const Duration(minutes: 10),
          dx: 1000,
          width: 1000,
          total: const Duration(hours: 1),
        ),
        const Duration(minutes: 12),
      );
    });

    test('never before the start or past the end', () {
      expect(
        seekTargetFor(
          from: const Duration(seconds: 2),
          dx: -900,
          width: 1000,
          total: short,
        ),
        Duration.zero,
      );
      expect(
        seekTargetFor(
          from: const Duration(seconds: 8),
          dx: 900,
          width: 1000,
          total: short,
        ),
        short,
      );
    });
  });

  group('track names', () {
    test('audio: its label, else its language, else "Track N"', () {
      const named = VideoAudioTrack(
        id: 'a',
        isSelected: true,
        label: 'English',
        language: 'en',
      );
      const languageOnly = VideoAudioTrack(
        id: 'b',
        isSelected: false,
        language: 'hi',
      );
      const nothing = VideoAudioTrack(id: 'c', isSelected: false);
      expect(audioTrackLabel(named, 0), 'English');
      expect(audioTrackLabel(languageOnly, 1), 'hi');
      expect(audioTrackLabel(nothing, 2), 'Track 3');
    });

    test('video: its height as "720p", else "Track N"', () {
      const hd = VideoTrack(id: 'v', isSelected: false, height: 720);
      const unknown = VideoTrack(id: 'w', isSelected: false);
      expect(videoTrackLabel(hd, 0), '720p');
      expect(videoTrackLabel(unknown, 1), 'Track 2');
    });
  });

  group('parseSubtitleFile', () {
    const srt =
        '﻿1\r\n00:00:01,000 --> 00:00:03,000\r\nHello\r\n\r\n'
        '2\r\n00:00:04,000 --> 00:00:05,500\r\nWorld\r\n';
    const vtt = 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nNamaste\n';

    test('reads SubRip with Windows line ends and a byte order mark', () {
      final file = parseSubtitleFile('movie.SRT', srt);
      expect(file, isNotNull);
      expect(file!.captions.map((c) => c.text), ['Hello', 'World']);
      expect(file.captions.first.start, const Duration(seconds: 1));
    });

    test('reads WebVTT', () {
      final file = parseSubtitleFile('movie.vtt', vtt);
      expect(file!.captions.single.text, 'Namaste');
    });

    test('anything else is not a subtitle file', () {
      expect(parseSubtitleFile('photo.jpg', 'not text'), isNull);
      expect(parseSubtitleFile('empty.srt', ''), isNull);
    });
  });
}
