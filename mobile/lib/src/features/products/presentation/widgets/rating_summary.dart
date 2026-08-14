part of '../../../../../main.dart';

class RatingSummary extends StatelessWidget {
  const RatingSummary({super.key, required this.product, this.compact = false});
  final Map<String, dynamic> product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rating = productRating(product);
    final count = productRatingCount(product);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          color: Colors.amber.shade700,
          size: compact ? 16 : 20,
        ),
        const SizedBox(width: 3),
        Text(
          rating == null ? 'New' : rating.toStringAsFixed(1),
          style: TextStyle(
            color: rating == null ? kTextColor : Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 12 : 14,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($count)',
            style: TextStyle(color: kTextColor, fontSize: compact ? 11 : 13),
          ),
        ],
      ],
    );
  }
}
