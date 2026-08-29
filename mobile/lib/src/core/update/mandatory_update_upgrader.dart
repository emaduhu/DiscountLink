part of '../../../main.dart';

class MandatoryUpdateUpgrader extends Upgrader {
  MandatoryUpdateUpgrader({super.durationUntilAlertAgain});

  @override
  bool blocked() => super.blocked() || isUpdateAvailable();
}
