part of '../../../../../main.dart';

ButtonStyle socialButtonStyle(BuildContext context) => OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(44),
  visualDensity: VisualDensity.compact,
  foregroundColor: appForegroundColor(context),
  side: BorderSide(color: appBorderColor(context)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);
