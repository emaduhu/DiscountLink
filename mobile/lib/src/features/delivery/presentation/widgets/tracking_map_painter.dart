part of '../../../../../main.dart';

class TrackingMapPainter extends CustomPainter {
  TrackingMapPainter({
    required this.shopLatitude,
    required this.shopLongitude,
    required this.delivererLatitude,
    required this.delivererLongitude,
    required this.textColor,
    required this.primary,
  });

  final double? shopLatitude;
  final double? shopLongitude;
  final double? delivererLatitude;
  final double? delivererLongitude;
  final Color textColor;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final dx = size.width * i / 4;
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final points = <_MapPoint>[
      if (shopLatitude != null && shopLongitude != null)
        _MapPoint('Shop', shopLatitude!, shopLongitude!, Colors.deepOrange),
      if (delivererLatitude != null && delivererLongitude != null)
        _MapPoint(
          'Deliverer',
          delivererLatitude!,
          delivererLongitude!,
          primary,
        ),
    ];
    if (points.isEmpty) return;

    final minLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    final minLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);
    final latSpan = (maxLat - minLat).abs() < 0.001 ? 0.001 : maxLat - minLat;
    final lngSpan = (maxLng - minLng).abs() < 0.001 ? 0.001 : maxLng - minLng;

    Offset project(_MapPoint point) {
      final x = 24 + ((point.longitude - minLng) / lngSpan) * (size.width - 48);
      final y = 24 + ((maxLat - point.latitude) / latSpan) * (size.height - 48);
      return Offset(x, y);
    }

    if (points.length > 1) {
      final routePaint = Paint()
        ..color = primary.withValues(alpha: 0.38)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawLine(project(points.first), project(points.last), routePaint);
    }

    for (final point in points) {
      final offset = project(point);
      canvas.drawCircle(offset, 10, Paint()..color = Colors.white);
      canvas.drawCircle(offset, 7, Paint()..color = point.color);
      _drawLabel(canvas, point.label, offset + const Offset(12, -24));
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
    final painter = TextPainter(text: span, textDirection: ui.TextDirection.ltr)
      ..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant TrackingMapPainter oldDelegate) =>
      oldDelegate.shopLatitude != shopLatitude ||
      oldDelegate.shopLongitude != shopLongitude ||
      oldDelegate.delivererLatitude != delivererLatitude ||
      oldDelegate.delivererLongitude != delivererLongitude;
}
