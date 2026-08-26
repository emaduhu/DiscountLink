part of '../../../../../main.dart';

class ThemeModeSwitch extends StatelessWidget {
  const ThemeModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        final picker = DropdownButtonHideUnderline(
          child: DropdownButton<ThemeMode>(
            value: themeMode,
            borderRadius: BorderRadius.circular(16),
            onChanged: (selection) {
              if (selection != null) {
                unawaited(setAppThemeMode(selection));
              }
            },
            items: ThemeMode.values
                .map(
                  (mode) => DropdownMenuItem<ThemeMode>(
                    value: mode,
                    child: Text(appThemeModeLabel(mode)),
                  ),
                )
                .toList(),
          ),
        );

        final details = Row(
          children: [
            CircleAvatar(
              backgroundColor: appPrimarySoftColor(context),
              child: Icon(appThemeModeIcon(themeMode), color: kPrimaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx('Theme', 'Mandhari'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    appThemeModeDescription(themeMode),
                    style: TextStyle(
                      color: appMutedTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 430) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: picker),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: details),
                picker,
              ],
            );
          },
        );
      },
    );
  }
}
