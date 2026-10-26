import 'package:flutter/material.dart';

/// Global keys — there is only ONE instance for the entire app, attached
/// at the root of the `MaterialApp`. This allows us to reliably display a
/// `SnackBar` from anywhere (regardless of which route/page is currently
/// mounted) — without needing to depend on the `BuildContext` of any
/// specific widget.
///
/// This becomes crucial in scenarios where a router refresh or rebuild
/// might otherwise dismiss a `SnackBar` prematurely (as we just observed) —
/// a global key remains immune to such rebuild cycles.
///
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();