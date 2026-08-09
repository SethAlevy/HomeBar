import 'package:flutter/material.dart';

// ============================================================================
// SearchField
// ----------------------------------------------------------------------------
// An inline search field meant to sit just below a screen's TopNavTiles
// (see IngredientsScreen/RecipesScreen). Owns its own TextEditingController
// purely so it can show/hide a clear button as text is typed, and reports
// every change up to the caller via onChanged, which is what actually
// drives filtering.
// ============================================================================
class SearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hintText;

  const SearchField({
    required this.onChanged,
    required this.hintText,
    super.key,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    // Only needed to hide the clear button itself - the actual filtering
    // update already happened via widget.onChanged above.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          widget.onChanged(value);
          // Only needed so the clear button appears/disappears as text is
          // typed/removed - filtering itself already happened above.
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Wyczyść',
                  onPressed: _clear,
                ),
          isDense: true,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
