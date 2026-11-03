import 'dart:async';

import 'package:flutter/material.dart';
import 'package:proalbums/core/theme/app_colors.dart';

/// The app's small message: a pill with the app icon and a short text (and
/// maybe one action such as "Undo"), like the system gallery's toasts.
///
///  - always at the SAME place: centred, just above the bottom bar (or
///    higher when the caller says what is under it, e.g. the viewer),
///  - 2 seconds (3.5 with an action, so there is time to tap it),
///  - one at a time: a new one replaces the old,
///  - colours from the theme (light and dark).
///
/// Take it BEFORE an await, like ScaffoldMessenger.of: the screen may be
/// gone when the message shows.
final class AppToast {
  AppToast._(this._overlay, this._defaultBottom);

  /// The toaster of the screen [context] is in.
  factory AppToast.of(BuildContext context) => AppToast._(
    Overlay.of(context, rootOverlay: true),
    // Above a bottom bar (navigation / selection bars are 64 high).
    MediaQuery.paddingOf(context).bottom + _barHeight + _gap,
  );

  static const double _barHeight = 64;
  static const double _gap = 12;
  static const Duration _short = Duration(seconds: 2);
  static const Duration _withAction = Duration(milliseconds: 3500);

  /// Where the app icon is (replace the file when the real icon is set).
  static const String iconAsset = 'assets/branding/app_icon.png';

  final OverlayState _overlay;
  final double _defaultBottom;

  // The toast on screen now (only ever one).
  static OverlayEntry? _entry;
  static GlobalKey<_ToastViewState>? _view;
  static Timer? _timer;

  /// Shows [text]. [bottomInset]: what covers the bottom of the screen here
  /// (e.g. the viewer's filmstrip + bar); 0 = the normal place above a bar.
  /// [actionLabel] + [onAction]: one button ("Undo").
  void show(
    String text, {
    double bottomInset = 0,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _removeNow();
    if (!_overlay.mounted) return;
    final hasAction = actionLabel != null && onAction != null;
    final key = GlobalKey<_ToastViewState>();
    final entry = OverlayEntry(
      builder: (context) => _ToastView(
        key: key,
        text: text,
        bottom: bottomInset > 0 ? bottomInset + _gap : _defaultBottom,
        actionLabel: hasAction ? actionLabel : null,
        onAction: hasAction
            ? () {
                _hide();
                onAction();
              }
            : null,
      ),
    );
    _entry = entry;
    _view = key;
    _overlay.insert(entry);
    _timer = Timer(hasAction ? _withAction : _short, _hide);
  }

  /// Fades the current toast out, then removes it.
  static void _hide() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    final view = _view?.currentState;
    if (entry == null) return;
    if (view == null) {
      _removeNow();
      return;
    }
    view.fadeOut().whenComplete(() {
      if (identical(_entry, entry)) _removeNow();
    });
  }

  static void _removeNow() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
    _view = null;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.text,
    required this.bottom,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String text;
  final double bottom;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  )..forward();

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  Future<void> fadeOut() => _controller.reverse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.actionLabel;
    return Positioned(
      left: 16,
      right: 16,
      bottom: widget.bottom,
      child: Center(
        child: FadeTransition(
          opacity: _curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(_curve),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Material(
                color: context.colors.pillSurface,
                elevation: 3,
                shape: StadiumBorder(
                  side: BorderSide(color: context.colors.dividerSubtle),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    10,
                    8,
                    action == null ? 18 : 6,
                    8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          AppToast.iconAsset,
                          width: 24,
                          height: 24,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: widget.onAction,
                          child: Text(action),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
