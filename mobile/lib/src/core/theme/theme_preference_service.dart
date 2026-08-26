part of '../../../main.dart';

class ThemePreferenceService {
  const ThemePreferenceService();

  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode';

  Future<ThemeMode> mode() async {
    final value = await _storage.read(key: _key);
    return themeModeFromStorageValue(value);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == ThemeMode.system) {
      await _storage.delete(key: _key);
      return;
    }
    await _storage.write(key: _key, value: mode.name);
  }
}

ThemeMode themeModeFromStorageValue(String? value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

Future<void> setAppThemeMode(ThemeMode mode) async {
  appThemeMode.value = mode;
  try {
    await themePreferences.setMode(mode);
  } catch (_) {}
}

String appThemeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => tx('System', 'Mfumo'),
    ThemeMode.light => tx('Light', 'Mwanga'),
    ThemeMode.dark => tx('Dark', 'Giza'),
  };
}

String appThemeModeDescription(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => tx(
      'Follow the device theme automatically.',
      'Fuata mandhari ya kifaa kiotomatiki.',
    ),
    ThemeMode.light => tx(
      'Use the light Discount Link theme.',
      'Tumia mandhari meupe ya Discount Link.',
    ),
    ThemeMode.dark => tx(
      'Use the dark Discount Link theme.',
      'Tumia mandhari meusi ya Discount Link.',
    ),
  };
}

IconData appThemeModeIcon(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };
}
