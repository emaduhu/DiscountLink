part of '../../../main.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://dl.vigourtech.net/api',
);
const kAppName = 'Discount Link';
const playStoreUrl = String.fromEnvironment(
  'PLAY_STORE_URL',
  defaultValue:
      'https://play.google.com/store/apps/details?id=net.vigourtech.dl',
);
const appStoreUrl = String.fromEnvironment(
  'APP_STORE_URL',
  defaultValue: 'https://apps.apple.com/search?term=Discount%20Link',
);
const googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);
const kPrimaryColor = Color(0xffff7643);
const kPrimaryColor2 = Color(0xffffa53e);
const kPrimaryLightColor = Color(0xffffecdf);
const kTextColor = Color(0xff757575);
const kSurfaceColor = Color(0xfff6f7fb);
const kDefaultPadding = 16.0;
const kTabletBreakpoint = 600.0;
const kResponsiveFormMaxWidth = 520.0;
const kResponsiveContentMaxWidth = 760.0;
const kResponsiveWideContentMaxWidth = 1040.0;
const kResponsiveChatMaxWidth = 720.0;
const kResponsiveNotificationMaxWidth = 560.0;
const kResponsiveSheetMaxWidth = 580.0;
const kSideMenuBreakpoint = 900.0;
const kSideMenuWidth = 204.0;
final appLanguage = ValueNotifier<AppLanguage>(AppLanguage.en);
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
const biometricAuth = BiometricAuthService();
const themePreferences = ThemePreferenceService();
const notificationPreferences = NotificationPreferenceService();
const notificationInbox = NotificationInboxService();
final networkActivity = NetworkActivityController();
final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final appNavigatorKey = GlobalKey<NavigatorState>();
