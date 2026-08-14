part of '../../../../../main.dart';

class _ProductPriceRow extends StatelessWidget {
  const _ProductPriceRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: highlighted ? kPrimaryColor : kTextColor,
      fontWeight: highlighted ? FontWeight.w900 : FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
