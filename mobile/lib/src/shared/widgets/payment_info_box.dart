part of '../../../main.dart';

class PaymentInfoBox extends StatelessWidget {
  const PaymentInfoBox({
    super.key,
    required this.icon,
    required this.text,
    this.active = false,
  });

  final IconData icon;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final mutedTextColor = appMutedTextColor(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? appPrimarySoftColor(context)
            : appSubtleSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? kPrimaryColor.withValues(alpha: 0.18)
              : appBorderColor(context),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: active ? kPrimaryColor : mutedTextColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: active ? kPrimaryColor : mutedTextColor,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
