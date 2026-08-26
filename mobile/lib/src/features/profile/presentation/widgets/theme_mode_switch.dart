part of '../../../../../main.dart';

class ThemeModeSwitch extends StatelessWidget {
  const ThemeModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        final selector = SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          selected: {themeMode},
          segments: ThemeMode.values
              .map(
                (mode) => ButtonSegment<ThemeMode>(
                  value: mode,
                  icon: Icon(appThemeModeIcon(mode), size: 18),
                  label: Text(appThemeModeLabel(mode)),
                ),
              )
              .toList(),
          onSelectionChanged: (selection) {
            unawaited(setAppThemeMode(selection.first));
          },
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: selector,
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                selector,
              ],
            );
          },
        );
      },
    );
  }
}
