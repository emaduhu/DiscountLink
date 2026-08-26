part of '../../../main.dart';

const kDarkScaffoldColor = Color(0xff0f1218);
const kDarkSurfaceColor = Color(0xff181d24);
const kDarkSubtleSurfaceColor = Color(0xff202633);
const kDarkTextColor = Color(0xfff3f5f8);
const kDarkMutedTextColor = Color(0xffaab2c0);

ThemeData discountLinkTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scaffoldColor = dark ? kDarkScaffoldColor : kSurfaceColor;
  final surfaceColor = dark ? kDarkSurfaceColor : Colors.white;
  final foregroundColor = dark ? kDarkTextColor : Colors.black87;
  final mutedColor = dark ? kDarkMutedTextColor : kTextColor;
  final borderColor = dark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.06);
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: kPrimaryColor,
        brightness: brightness,
      ).copyWith(
        primary: kPrimaryColor,
        secondary: kPrimaryColor2,
        surface: surfaceColor,
        onSurface: foregroundColor,
      );
  final baseTheme = ThemeData(colorScheme: colorScheme, useMaterial3: true);

  return baseTheme.copyWith(
    scaffoldBackgroundColor: scaffoldColor,
    canvasColor: scaffoldColor,
    cardColor: surfaceColor,
    textTheme: baseTheme.textTheme.apply(
      bodyColor: foregroundColor,
      displayColor: foregroundColor,
    ),
    primaryTextTheme: baseTheme.primaryTextTheme.apply(
      bodyColor: foregroundColor,
      displayColor: foregroundColor,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: scaffoldColor,
      foregroundColor: foregroundColor,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    dividerTheme: DividerThemeData(color: borderColor),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      labelStyle: TextStyle(color: mutedColor),
      hintStyle: TextStyle(color: mutedColor.withValues(alpha: 0.82)),
      prefixIconColor: mutedColor,
      suffixIconColor: mutedColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceColor,
      indicatorColor: dark
          ? kPrimaryColor.withValues(alpha: 0.22)
          : kPrimaryLightColor,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? kDarkSubtleSurfaceColor : Colors.black87,
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
  );
}

bool appIsDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color appSurfaceColor(BuildContext context) => Theme.of(context).cardColor;

Color appSubtleSurfaceColor(BuildContext context) =>
    appIsDark(context) ? kDarkSubtleSurfaceColor : kSurfaceColor;

Color appForegroundColor(BuildContext context) =>
    appIsDark(context) ? kDarkTextColor : Colors.black87;

Color appTitleColor(BuildContext context) =>
    appIsDark(context) ? kDarkTextColor : Colors.black;

Color appMutedTextColor(BuildContext context) =>
    appIsDark(context) ? kDarkMutedTextColor : kTextColor;

Color appBorderColor(BuildContext context) => appIsDark(context)
    ? Colors.white.withValues(alpha: 0.08)
    : Colors.black.withValues(alpha: 0.06);

Color appPrimarySoftColor(BuildContext context) => appIsDark(context)
    ? kPrimaryColor.withValues(alpha: 0.18)
    : kPrimaryLightColor;

Color appShadowColor(
  BuildContext context, {
  double lightAlpha = 0.06,
  double darkAlpha = 0.24,
}) =>
    Colors.black.withValues(alpha: appIsDark(context) ? darkAlpha : lightAlpha);
