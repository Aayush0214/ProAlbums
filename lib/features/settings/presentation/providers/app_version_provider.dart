import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version_provider.g.dart';

/// The installed app's version as Settings shows it ("V1.0.0"), from the
/// build itself (pubspec version), never typed by hand.
@Riverpod(keepAlive: true)
Future<String> appVersion(Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'V${info.version}';
}
