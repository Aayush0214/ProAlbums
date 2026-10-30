
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/features/gallery/data/datasources/system_thumbnail_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.aayush.proalbums/thumbnails');
  const source = MethodChannelSystemThumbnailSource();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mock(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  test('sends id, size and type, returns the bytes', () async {
    MethodCall? received;
    mock((call) async {
      received = call;
      return Uint8List.fromList([1, 2, 3]);
    });

    final bytes = await source.load(id: '42', size: 288, isVideo: true);

    expect(bytes, [1, 2, 3]);
    expect(received?.method, 'load');
    expect(received?.arguments, {'id': '42', 'size': 288, 'isVideo': true});
  });

  test('an error on the phone becomes null (so the old way is used)', () async {
    mock((call) async => throw PlatformException(code: 'x'));
    expect(await source.load(id: '1', size: 96, isVideo: false), isNull);
  });

  test('no native side (not Android) becomes null', () async {
    expect(await source.load(id: '1', size: 96, isVideo: false), isNull);
  });
}
