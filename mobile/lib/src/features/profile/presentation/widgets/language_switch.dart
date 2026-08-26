part of '../../../../../main.dart';

class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) => Row(
        children: [
          CircleAvatar(
            backgroundColor: appPrimarySoftColor(context),
            child: const Icon(Icons.language, color: kPrimaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx('Language', 'Lugha'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  tx('Choose app language', 'Chagua lugha ya programu'),
                  style: TextStyle(
                    color: appMutedTextColor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SegmentedButton<AppLanguage>(
            segments: const [
              ButtonSegment(value: AppLanguage.en, label: Text('EN')),
              ButtonSegment(value: AppLanguage.sw, label: Text('SW')),
            ],
            selected: {language},
            onSelectionChanged: (selection) {
              appLanguage.value = selection.first;
            },
          ),
        ],
      ),
    );
  }
}
