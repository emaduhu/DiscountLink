part of '../../../../../main.dart';

class TrackingMiniMap extends StatelessWidget {
  const TrackingMiniMap({
    super.key,
    required this.shopLatitude,
    required this.shopLongitude,
    required this.delivererLatitude,
    required this.delivererLongitude,
  });

  final double? shopLatitude;
  final double? shopLongitude;
  final double? delivererLatitude;
  final double? delivererLongitude;

  @override
  Widget build(BuildContext context) {
    final hasDeliverer =
        delivererLatitude != null && delivererLongitude != null;
    return SizedBox(
      height: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xffe8f3f1),
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: TrackingMapPainter(
                  shopLatitude: shopLatitude,
                  shopLongitude: shopLongitude,
                  delivererLatitude: delivererLatitude,
                  delivererLongitude: delivererLongitude,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  primary: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (!hasDeliverer)
                const Center(
                  child: Text('Deliverer location has not been shared yet'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
