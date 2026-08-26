part of '../../../main.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: Column(
        children: [
          Icon(icon, color: appMutedTextColor(context), size: 44),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: appMutedTextColor(context)),
          ),
        ],
      ),
    );
  }
}
