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
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        fixedSize: const Size(38, 38),
        backgroundColor: filled ? kPrimaryColor : Colors.white,
        foregroundColor: filled ? Colors.white : Colors.black87,
        side: filled
            ? BorderSide.none
            : BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        shape: const CircleBorder(),
      ),
    );
  }
}
