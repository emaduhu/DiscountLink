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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? kPrimaryLightColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? kPrimaryColor.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: active ? kPrimaryColor : kTextColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: active ? kPrimaryColor : kTextColor,
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
