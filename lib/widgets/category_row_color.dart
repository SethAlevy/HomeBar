import 'package:flutter/material.dart';

// ============================================================================
// categoryRowColor
// ----------------------------------------------------------------------------
// One hue throughout (the app's own orange), stepping down in lightness by
// depth - subtly, so a whole category tree still reads as "one uniform
// table" while the tint shift shows which rows are nested inside which.
// Shared by TemplateContentScreen's editable tree and CategoryBrowserScreen's
// read-only tree, so both look like the same kind of table.
// ============================================================================
const double categoryRowHue = 32;
const double categoryRowSaturation = 0.35;

Color categoryRowColor(int depth) {
  final lightness = (0.94 - depth * 0.035).clamp(0.80, 0.94);
  return HSLColor.fromAHSL(1.0, categoryRowHue, categoryRowSaturation, lightness).toColor();
}
