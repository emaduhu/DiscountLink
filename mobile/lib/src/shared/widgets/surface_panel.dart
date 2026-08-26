part of '../../../main.dart';

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: appShadowColor(context),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}
