part of '../../../../../main.dart';

class ProductDealCard extends StatelessWidget {
  const ProductDealCard({
    super.key,
    required this.product,
    required this.money,
    required this.imageAsset,
    required this.onAdd,
    required this.onStartChat,
    required this.onShare,
    required this.onRate,
  });
  final Map<String, dynamic> product;
  final NumberFormat money;
  final String imageAsset;
  final Future<void> Function() onAdd;
  final Future<void> Function() onStartChat;
  final Future<void> Function() onShare;
  final Future<void> Function(int rating) onRate;

  @override
  Widget build(BuildContext context) {
    final actual = productActualPrice(product);
    final itemPrice = productBuyerPrice(product);
    final discount = productDiscountPercent(product);
    final hasDiscount = productHasDiscount(product);
    final matchPercent = productImageMatchPercent(product);
    final videoCount = productVideoCount(product);
    final shopOpen = product['shop']?['is_open'] == true;
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => ProductQuickView(
            product: product,
            money: money,
            imageAsset: imageAsset,
            onAdd: onAdd,
            onStartChat: onStartChat,
            onShare: onShare,
            onRate: onRate,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: kSurfaceColor),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: ProductImage(
                              source: imageAsset,
                              fit: BoxFit.contain,
                            ),
                          ),
                          if (matchPercent != null)
                            Align(
                              alignment: Alignment.topLeft,
                              child: _ProductBadge(
                                label: '$matchPercent% match',
                                color: Colors.black87,
                              ),
                            ),
                          if (hasDiscount)
                            Align(
                              alignment: Alignment.topRight,
                              child: _ProductBadge(
                                label: discount > 0
                                    ? '${discount.toStringAsFixed(0)}% off'
                                    : 'Deal',
                                color: kPrimaryColor,
                              ),
                            ),
                          if (videoCount > 0)
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: _ProductBadge(
                                label:
                                    '$videoCount video${videoCount == 1 ? '' : 's'}',
                                color: Colors.black87,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  product['name'] ?? 'Product',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product['shop']?['name'] ?? ''} · ${shopOpen ? 'Open' : 'Closed'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: shopOpen
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                RatingSummary(product: product, compact: true),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TZS ${money.format(itemPrice)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _ProductIconAction(
                      tooltip: tx('Add to cart', 'Weka kikapuni'),
                      onPressed: onAdd,
                      icon: Icons.add_shopping_cart,
                      filled: true,
                    ),
                  ],
                ),
                if (hasDiscount)
                  Text(
                    'TZS ${money.format(actual)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kTextColor,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
