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
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: kTextColor)),
        ),
        Text(
          value,
          style: TextStyle(
            color: strong ? Colors.black : kTextColor,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
