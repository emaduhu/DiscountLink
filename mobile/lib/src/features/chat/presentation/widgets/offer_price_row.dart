part of '../../../../../main.dart';

class _OfferPriceRow extends StatelessWidget {
  const _OfferPriceRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final mutedTextColor = appMutedTextColor(context);
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: mutedTextColor)),
        ),
        Text(
          value,
          style: TextStyle(
            color: strong ? appForegroundColor(context) : mutedTextColor,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
