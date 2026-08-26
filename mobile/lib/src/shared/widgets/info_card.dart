part of '../../../main.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(color: appMutedTextColor(context), height: 1.35),
        ),
      ],
    ),
  );
}
