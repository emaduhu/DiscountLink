part of '../../../main.dart';

class ClickPesaResendPromptButton extends StatelessWidget {
  const ClickPesaResendPromptButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final gradientColors = appIsDark(context)
        ? const [kDarkSubtleSurfaceColor, kDarkSurfaceColor]
        : const [Color(0xfffffbf8), Color(0xffffecdf)];
    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kPrimaryColor.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kPrimaryColor, kPrimaryColor2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.refresh_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: appForegroundColor(context),
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: enabled ? kPrimaryColor : appMutedTextColor(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
