part of '../../../../../main.dart';

class _ProductIconAction extends StatelessWidget {
  const _ProductIconAction({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.filled = false,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = appSurfaceColor(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        fixedSize: const Size(38, 38),
        backgroundColor: filled ? kPrimaryColor : surfaceColor,
        foregroundColor: filled ? Colors.white : appForegroundColor(context),
        side: filled
            ? BorderSide.none
            : BorderSide(color: appBorderColor(context)),
        shape: const CircleBorder(),
      ),
    );
  }
}
