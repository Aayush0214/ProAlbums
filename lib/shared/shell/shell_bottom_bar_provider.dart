import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shell_bottom_bar_provider.g.dart';

/// Lets a tab hide the main navigation bar (for example while selecting
/// photos, when an action bar takes its place).
///
/// Every caller uses its own [owner] name, so two screens can never show the
/// bar again while the other one still wants it hidden.
@Riverpod(keepAlive: true)
class ShellBottomBarHidden extends _$ShellBottomBarHidden {
  final Set<String> _owners = <String>{};

  @override
  bool build() => false;

  void hide(String owner) {
    _owners.add(owner);
    state = true;
  }

  void show(String owner) {
    _owners.remove(owner);
    state = _owners.isNotEmpty;
  }
}
