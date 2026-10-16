import 'package:flutter/material.dart';

/// Visual placeholder used instead of real product photos in this UI phase.
class ItemGlyph {
  const ItemGlyph(this.key, this.label, this.icon, this.color);

  final String key;
  final String label;
  final IconData icon;
  final Color color;

  static const List<ItemGlyph> all = [
    ItemGlyph('panel', 'Panel', Icons.solar_power_rounded, Color(0xFF1565C0)),
    ItemGlyph('inverter', 'Inverter', Icons.bolt_rounded, Color(0xFFF2A623)),
    ItemGlyph('battery', 'Battery', Icons.battery_charging_full_rounded, Color(0xFF2E7D32)),
    ItemGlyph('cable', 'Cable', Icons.cable_rounded, Color(0xFF6A1B9A)),
    ItemGlyph('structure', 'Structure', Icons.hardware_rounded, Color(0xFF546E7A)),
    ItemGlyph('light', 'Light', Icons.lightbulb_outline_rounded, Color(0xFFEF6C00)),
    ItemGlyph('tool', 'Tool', Icons.handyman_rounded, Color(0xFF00838F)),
    ItemGlyph('box', 'Box', Icons.inventory_2_rounded, Color(0xFF455A64)),
  ];

  static ItemGlyph byKey(String key) =>
      all.firstWhere((g) => g.key == key, orElse: () => all.first);
}
