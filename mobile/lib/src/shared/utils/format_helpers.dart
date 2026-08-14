part of '../../../main.dart';

String formatDateTime(dynamic value) {
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('MMM d, HH:mm').format(parsed.toLocal());
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return letters.isEmpty ? 'DL' : letters;
}

String otpProviderLabel(String provider) => switch (provider) {
  'firebase' => 'Firebase',
  'infobip' => 'Infobip',
  _ => 'Beem Africa',
};
