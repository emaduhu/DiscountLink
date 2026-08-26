part of '../../../../../main.dart';

class ProductPriceBreakdown extends StatelessWidget {
  const ProductPriceBreakdown({
    super.key,
    required this.product,
    required this.money,
  });

  final Map<String, dynamic> product;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final actual = productActualPrice(product);
    final buyerPrice = productBuyerPrice(product);
    final delivery = productDeliveryPrice(product);
    final total = productTotalPrice(product);
    final hasDiscount = productHasDiscount(product);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appIsDark(context)
            ? kPrimaryColor.withValues(alpha: 0.16)
            : kPrimaryLightColor.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TZS ${money.format(buyerPrice)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 10),
                Text(
                  'TZS ${money.format(actual)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: appMutedTextColor(context),
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (hasDiscount)
            Divider(height: 12, color: kPrimaryColor.withValues(alpha: 0.12)),
          _ProductPriceRow(
            label: 'Delivery',
            value: 'TZS ${money.format(delivery)}',
          ),
          const Divider(height: 16),
          _ProductPriceRow(
            label: 'Total',
            value: 'TZS ${money.format(total)}',
            highlighted: true,
          ),
        ],
      ),
    );
  }
}
