import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/core/platform/app_orientation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.aayush.proalbums/orientation');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Object? sentToFlutter;

  setUp(() {
    sentToFlutter = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        sentToFlutter = call.arguments;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('lockPortrait allows only portrait', () async {
    await AppOrientation.lockPortrait();
    expect(sentToFlutter, ['DeviceOrientation.portraitUp']);
  });

  test('allowRotation asks the phone for sensor rotation', () async {
    String? method;
    messenger.setMockMethodCallHandler(channel, (call) async {
      method = call.method;
      return null;
    });

    await AppOrientation.allowRotation();

    expect(method, 'sensor');
    expect(sentToFlutter, isNull); // the native way worked, no fallback
  });

  test('allowRotation falls back to all four directions without the native side',
      () async {
    await AppOrientation.allowRotation();
    expect(sentToFlutter, hasLength(4));
  });
}
