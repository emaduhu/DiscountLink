part of '../../../../../main.dart';

class TrackingCard extends StatelessWidget {
  const TrackingCard({super.key, required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final assignment = order['delivery_assignment'] as Map<String, dynamic>?;
    final deliverer = assignment?['deliverer'] as Map<String, dynamic>?;
    final shop = order['shop'] as Map<String, dynamic>?;
    final updatedAt = assignment?['location_updated_at'];
    final delivererLatitude = toDouble(assignment?['deliverer_latitude']);
    final delivererLongitude = toDouble(assignment?['deliverer_longitude']);
    final items = (order['items'] as List?) ?? [];
    final money = NumberFormat('#,##0.00');
    final deliveryCode = '${order['delivery_code'] ?? ''}'.trim();
    final deliveryCodeNotice =
        '${order['delivery_code_notice'] ?? 'Share this code only after the order arrives. It releases seller and delivery payments.'}';
    final mutedTextColor = appMutedTextColor(context);
    final deliveryCodeBackgroundColor = appIsDark(context)
        ? kPrimaryColor.withValues(alpha: 0.16)
        : kPrimaryLightColor;
    final deliveryCodeTextColor = appIsDark(context)
        ? kDarkTextColor
        : Colors.black87;

    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order['reference'] ?? 'Order',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(
                label: '${order['status'] ?? 'active'}',
                color: kPrimaryColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order['delivery_address'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: mutedTextColor),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final item in items.take(3))
              Text(
                '${item['quantity']}x ${item['name']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            'Total TZS ${money.format(num.tryParse('${order['grand_total']}') ?? 0)}',
            style: const TextStyle(
              color: kPrimaryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (deliveryCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: deliveryCodeBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: kPrimaryColor.withValues(
                    alpha: appIsDark(context) ? 0.24 : 0.10,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_outlined, color: kPrimaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buyer delivery code\n$deliveryCode',
                      style: TextStyle(
                        color: deliveryCodeTextColor,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              deliveryCodeNotice,
              style: TextStyle(
                color: mutedTextColor,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 10),
          TrackingMiniMap(
            shopLatitude: toDouble(shop?['latitude']),
            shopLongitude: toDouble(shop?['longitude']),
            delivererLatitude: delivererLatitude,
            delivererLongitude: delivererLongitude,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.delivery_dining_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deliverer == null
                      ? 'Waiting for a deliverer'
                      : '${deliverer['name']} ${updatedAt == null ? '' : '- updated ${formatDateTime(updatedAt)}'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
