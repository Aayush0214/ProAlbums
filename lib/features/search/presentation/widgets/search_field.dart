import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/core/theme/app_colors.dart';

/// The "Search for photos" pill: 🔍, the text, ✕ while there is text.
/// Without a [controller] it is only a button (the Search tab's bar, which
/// opens the search page).
class SearchField extends StatelessWidget {
  const SearchField({
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  static const String _hint = 'Search for photos';

  @override
  Widget build(BuildContext context) {
    final hintStyle = context.textTheme.bodyLarge?.copyWith(
      color: context.colors.textSecondary,
    );
    final controller = this.controller;
    return Material(
      color: context.colorScheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: controller == null ? onTap : null,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 6),
            child: Row(
              children: [
                Icon(
                  LucideIcons.search,
                  size: 22,
                  color: context.colors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: controller == null
                      ? Text(_hint, style: hintStyle)
                      : TextField(
                          controller: controller,
                          focusNode: focusNode,
                          autofocus: autofocus,
                          onChanged: onChanged,
                          onSubmitted: onSubmitted,
                          textInputAction: TextInputAction.search,
                          style: context.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: _hint,
                            hintStyle: hintStyle,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isCollapsed: true,
                          ),
                        ),
                ),
                if (controller != null && onClear != null)
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => controller.text.isEmpty
                        ? const SizedBox(width: 8)
                        : IconButton(
                            tooltip: 'Clear',
                            visualDensity: VisualDensity.compact,
                            onPressed: onClear,
                            icon: Icon(
                              LucideIcons.circleX,
                              size: 20,
                              color: context.colors.textSecondary,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
