part of '../../../main.dart';

String normalizePhoneInput(String value) {
  final trimmed = value.trim();
  final withoutCountryPrefix = trimmed.startsWith('+')
      ? trimmed.substring(1)
      : trimmed;
  return withoutCountryPrefix.replaceAll(RegExp(r'[\s-]+'), '');
}

String normalizeLoginIdentifier(String value) {
  final trimmed = value.trim();
  return trimmed.contains('@')
      ? trimmed.toLowerCase()
      : normalizePhoneInput(trimmed);
}

bool isTwelveDigitPhone(String value) =>
    RegExp(r'^\d{12}$').hasMatch(normalizePhoneInput(value));

String requireTwelveDigitPhone(String value) {
  final phone = normalizePhoneInput(value);
  if (!RegExp(r'^\d{12}$').hasMatch(phone)) {
    throw Exception(
      tx(
        'Phone number must contain exactly 12 digits, for example 255700000001.',
        'Namba ya simu lazima iwe na tarakimu 12, mfano 255700000001.',
      ),
    );
  }
  return phone;
}
