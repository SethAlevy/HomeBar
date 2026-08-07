import 'package:flutter/material.dart';

// ============================================================================
// TopNavTiles
// ----------------------------------------------------------------------------
// A small, reusable pair of navigation shortcuts shown at the top of a
// screen's body: one to go back to the previous screen, one to jump
// straight back to the very first screen (home). Pulled out into its own
// widget so every screen that wants this row can just write
// `const TopNavTiles()` instead of duplicating the layout code.
// ============================================================================
class TopNavTiles extends StatelessWidget {
  const TopNavTiles({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          // Expanded makes each tile share the row equally (50/50), so
          // both buttons stay the same width regardless of label length.
          Expanded(
            child: _NavTile(
              icon: Icons.arrow_back,
              label: 'Wróć',
              // Navigator.pop() removes the current screen from the
              // navigation stack, revealing whatever was pushed before it.
              onTap: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _NavTile(
              icon: Icons.home_outlined,
              label: 'Strona główna',
              // popUntil() keeps popping screens off the stack until the
              // predicate is true; `route.isFirst` matches only the very
              // first screen ever pushed (HomeScreen), so this jumps all
              // the way back regardless of how deep the user has
              // navigated.
              onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
            ),
          ),
        ],
      ),
    );
  }
}

// Private helper widget (the leading underscore means it's only visible
// within this file) that renders one tappable, card-styled button used by
// both tiles above.
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      // Clip.antiAlias makes the InkWell's ripple effect respect the
      // card's rounded corners instead of spilling outside them.
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        // InkWell adds Material's tap ripple/highlight feedback around
        // whatever it wraps, on top of handling the actual tap.
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
