/// Asks "can the app see ANY photo or video right now?".
///
/// Needed for limited access: the person may allow "selected photos" and
/// select none, which is different from an empty phone.
abstract interface class VisibleMediaRepository {
  Future<bool> hasAny();
}
