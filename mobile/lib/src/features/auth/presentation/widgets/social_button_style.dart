part of '../../../../../main.dart';

ButtonStyle socialButtonStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(44),
  visualDensity: VisualDensity.compact,
  foregroundColor: Colors.black,
  side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);
