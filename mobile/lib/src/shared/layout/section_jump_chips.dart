part of '../../../main.dart';

class SectionJumpChips extends StatelessWidget {
  const SectionJumpChips({super.key, required this.title, required this.items});

  final String title;
  final List<SectionMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: kTextColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  ActionChip(
                    avatar: Icon(items[index].icon, size: 18),
                    label: Text(items[index].label),
                    onPressed: () => jumpToSection(items[index].key),
                  ),
                  if (index != items.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
