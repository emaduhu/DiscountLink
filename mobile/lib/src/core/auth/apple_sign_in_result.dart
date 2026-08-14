part of '../../../main.dart';

class AppleSignInResult {
  const AppleSignInResult({
    required this.credential,
    this.email,
    this.displayName,
  });

  final UserCredential credential;
  final String? email;
  final String? displayName;
}
