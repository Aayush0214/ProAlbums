/// What the app is currently allowed to do with the user's gallery.
enum MediaPermissionStatus {
  /// Never asked yet (iOS). On Android the first check usually says [denied].
  notDetermined,

  /// Full access to photos and videos.
  granted,

  /// User picked only some items (iOS "Limited", Android 14 "Select photos").
  limited,

  /// Denied. Android cannot tell "denied once" from "denied forever", so the
  /// UI always offers both "Try again" and "Open Settings".
  denied,

  /// Blocked by a device policy such as parental controls (iOS).
  restricted;

  /// Limited access still lets us show the gallery (with the picked items).
  bool get hasAccess => this == granted || this == limited;
}
