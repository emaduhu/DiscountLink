part of '../../../../../main.dart';

class ProductQuickView extends StatelessWidget {
  const ProductQuickView({
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    final media = productMediaSources(product, fallback: imageAsset);
    final matchPercent = productImageMatchPercent(product);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kDefaultPadding),
          child: ResponsiveCenter(
            maxWidth: kResponsiveSheetMaxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductMediaCarousel(media: media),
                const SizedBox(height: 12),
                Text(
                  product['name'] ?? 'Product',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product['description'] ?? '',
                  style: const TextStyle(color: kTextColor),
                ),
                if (product['shop'] is Map) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final shop = product['shop'] as Map;
                      final open = shop['is_open'] == true;
                      return StatusPill(
                        label:
                            '${open ? 'Open now' : 'Closed now'} · ${shop['opening_time'] ?? '--:--'}–${shop['closing_time'] ?? '--:--'}',
                        color: open
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      );
                    },
                  ),
                ],
                if (matchPercent != null) ...[
                  const SizedBox(height: 8),
                  StatusPill(
                    label: '$matchPercent% visual match',
                    color: Colors.black87,
                  ),
                ],
                const SizedBox(height: 10),
                RatingSummary(product: product),
                const SizedBox(height: 8),
                RatingPicker(onRate: onRate),
                const SizedBox(height: 12),
                ProductPriceBreakdown(product: product, money: money),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await onAdd();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to cart'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('Share download link'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await onStartChat();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Start chat with seller'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
