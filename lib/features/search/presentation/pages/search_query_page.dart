import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proalbums/features/search/presentation/search_providers.dart';
import 'package:proalbums/features/search/presentation/widgets/search_answers.dart';
import 'package:proalbums/features/search/presentation/widgets/search_field.dart';
import 'package:proalbums/features/search/presentation/widgets/search_home.dart';

/// The search page (a page of its own inside the Search tab): the bar +
/// "Cancel" at the top, Recent searches while nothing is typed, else the
/// answers. Back / Cancel close it (back to the Search tab).
class SearchQueryPage extends ConsumerStatefulWidget {
  const SearchQueryPage({this.initialText = '', super.key});

  /// Searched at once (a recent search was tapped); empty = start typing.
  final String initialText;

  @override
  ConsumerState<SearchQueryPage> createState() => _SearchQueryPageState();
}

class _SearchQueryPageState extends ConsumerState<SearchQueryPage> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialText,
  );
  final FocusNode _focus = FocusNode();

  /// What is searched (the typed text, a moment after the last key).
  late String _query = widget.initialText.trim();
  Timer? _typing;

  static const Duration _typingPause = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    // A recent search was tapped: it moves up in Recent searches.
    if (_query.isNotEmpty) _remember(_query);
  }

  @override
  void dispose() {
    _typing?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _typing?.cancel();
    _typing = Timer(_typingPause, () => _setQuery(text));
  }

  void _setQuery(String text) {
    if (mounted) setState(() => _query = text.trim());
  }

  /// Search [text] now (a recent search tapped on this page).
  void _searchNow(String text) {
    _typing?.cancel();
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.unfocus();
    _setQuery(text);
    _remember(text);
  }

  void _remember(String text) =>
      unawaited(ref.read(recentSearchesProvider.notifier).add(text));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    controller: _text,
                    focusNode: _focus,
                    autofocus: widget.initialText.isEmpty,
                    onChanged: _onChanged,
                    onSubmitted: (text) {
                      _setQuery(text);
                      _remember(text);
                    },
                    onClear: () {
                      _typing?.cancel();
                      _text.clear();
                      _setQuery('');
                      _focus.requestFocus();
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? CustomScrollView(
                    slivers: [SearchRecent(onRecent: _searchNow)],
                  )
                : SearchAnswers(
                    query: _query,
                    onOpen: (remember) {
                      _focus.unfocus();
                      _remember(remember);
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
