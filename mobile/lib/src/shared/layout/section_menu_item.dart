part of '../../../main.dart';

class SectionMenuItem {
  const SectionMenuItem({
    required this.label,
    required this.icon,
    required this.key,
  });

  final String label;
  final IconData icon;
  final GlobalKey key;
}
