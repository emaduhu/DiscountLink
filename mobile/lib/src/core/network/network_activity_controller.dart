part of '../../../main.dart';

class NetworkActivityController {
  final activeRequests = ValueNotifier<int>(0);

  void begin() {
    activeRequests.value += 1;
  }

  void end() {
    if (activeRequests.value == 0) return;
    activeRequests.value -= 1;
  }

  Future<void> waitForVisible() async {
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<T> run<T>(Future<T> Function() action) async {
    begin();
    try {
      await waitForVisible();
      return await action();
    } finally {
      end();
    }
  }
}
