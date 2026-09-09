part of '../../../../main.dart';

double? productRating(Map<String, dynamic> product) {
  final value = product['ratings_avg_rating'];
  if (value == null) return null;
  return double.tryParse('$value');
}

int productRatingCount(Map<String, dynamic> product) {
  final value = product['ratings_count'];
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}

double productActualPrice(Map<String, dynamic> product) {
  return (num.tryParse('${product['price'] ?? 0}') ?? 0).toDouble();
}

double productDiscountPercent(Map<String, dynamic> product) {
  final value = (num.tryParse('${product['discount_percent'] ?? 0}') ?? 0)
      .toDouble();
  return value.clamp(0, 100).toDouble();
}

const productDiscountModePercent = 'percent';
const productDiscountModeAmount = 'amount';

double? productDiscountPrice(Map<String, dynamic> product) {
  final explicit = num.tryParse('${product['discount_price'] ?? ''}');
  if (explicit != null) return explicit.toDouble();

  final actual = productActualPrice(product);
  final percent = productDiscountPercent(product);
  if (actual <= 0 || percent <= 0) return null;

  return ((actual * (1 - (percent / 100))) * 100).roundToDouble() / 100;
}

double? productDiscountAmountOff(Map<String, dynamic> product) {
  final actual = productActualPrice(product);
  final discounted = productDiscountPrice(product);
  if (actual <= 0 || discounted == null || discounted >= actual) return null;

  return ((actual - discounted) * 100).roundToDouble() / 100;
}

String productDiscountModeForProduct(Map<String, dynamic> product) {
  if (productDiscountPercent(product) > 0) return productDiscountModePercent;
  if ((productDiscountAmountOff(product) ?? 0) > 0) {
    return productDiscountModeAmount;
  }
  return productDiscountModePercent;
}

String productDiscountValueForMode(Map<String, dynamic> product, String mode) {
  final value = mode == productDiscountModeAmount
      ? productDiscountAmountOff(product) ?? 0
      : productDiscountPercent(product);
  return compactDecimal(value);
}

String compactDecimal(num value) {
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

Map<String, String> productDiscountMultipartFields({
  required String priceText,
  required String discountMode,
  required String discountText,
}) {
  if (discountMode == productDiscountModeAmount) {
    final price = requiredProductPrice(priceText);
    final amount = optionalDiscountAmount(discountText);
    if (amount > price) {
      throw Exception('Discount amount cannot be greater than product price.');
    }

    return {
      'discount_percent': '0',
      if (amount > 0) 'discount_price': compactDecimal(price - amount),
    };
  }

  return {
    'discount_percent': discountText.trim().isEmpty ? '0' : discountText.trim(),
  };
}

Map<String, dynamic> productDiscountJsonFields({
  required String priceText,
  required String discountMode,
  required String discountText,
}) {
  final fields = productDiscountMultipartFields(
    priceText: priceText,
    discountMode: discountMode,
    discountText: discountText,
  );

  return {
    'discount_percent': double.tryParse(fields['discount_percent'] ?? '0') ?? 0,
    if (fields['discount_price'] != null)
      'discount_price': double.parse(fields['discount_price']!),
  };
}

double requiredProductPrice(String value) {
  final price = double.tryParse(value.trim());
  if (price == null || price < 0) {
    throw Exception('Enter a valid product price.');
  }
  return price;
}

double optionalDiscountAmount(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 0;

  final amount = double.tryParse(trimmed);
  if (amount == null || amount < 0) {
    throw Exception('Enter a valid discount amount.');
  }
  return amount;
}

double productBuyerPrice(Map<String, dynamic> product) {
  final actual = productActualPrice(product);
  final discounted = productDiscountPrice(product);
  if (discounted == null || discounted >= actual) return actual;
  return discounted;
}

double productDeliveryPrice(Map<String, dynamic> product) {
  return (num.tryParse('${product['delivery_price'] ?? 0}') ?? 0).toDouble();
}

double productTotalPrice(Map<String, dynamic> product) {
  return productBuyerPrice(product) + productDeliveryPrice(product);
}

bool productHasDiscount(Map<String, dynamic> product) {
  return productBuyerPrice(product) < productActualPrice(product);
}

int? productImageMatchPercent(Map<String, dynamic> product) {
  final value = product['image_match_percent'];
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse('$value');
}

String productImageSource(
  Map<String, dynamic> product, {
  required String fallback,
}) {
  return productImageSources(product, fallback: fallback).first;
}

String normalizeMediaSource(String source) {
  final trimmed = source.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return trimmed;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return trimmed;
  }

  final apiUri = Uri.tryParse(apiBaseUrl);
  if (apiUri == null || !apiUri.hasAuthority) {
    return trimmed;
  }

  final mediaHost = uri.host.toLowerCase();
  final apiHost = apiUri.host.toLowerCase();
  final pointsAtLocalhost =
      mediaHost == 'localhost' ||
      mediaHost == '127.0.0.1' ||
      mediaHost == '0.0.0.0';
  final cleartextSameHost =
      uri.scheme == 'http' && apiUri.scheme == 'https' && mediaHost == apiHost;
  if (!pointsAtLocalhost && !cleartextSameHost) {
    return trimmed;
  }

  return Uri(
    scheme: apiUri.scheme,
    host: apiUri.host,
    port: apiUri.hasPort ? apiUri.port : null,
    path: uri.path,
    query: uri.hasQuery ? uri.query : null,
    fragment: uri.hasFragment ? uri.fragment : null,
  ).toString();
}

List<String> productImageSources(
  Map<String, dynamic> product, {
  required String fallback,
}) {
  final images = product['images'];
  if (images is List) {
    final sources = images
        .map((image) => normalizeMediaSource('$image'))
        .where((image) => image.isNotEmpty)
        .toList();
    if (sources.isNotEmpty) return sources;
  }
  return [fallback];
}

List<Map<String, dynamic>> productMediaSources(
  Map<String, dynamic> product, {
  required String fallback,
}) {
  final media = product['media'];
  if (media is List) {
    final sources =
        media
            .whereType<Map>()
            .map((item) {
              final next = Map<String, dynamic>.from(item);
              next['url'] = normalizeMediaSource('${next['url'] ?? ''}');
              return next;
            })
            .where((item) => '${item['url'] ?? ''}'.trim().isNotEmpty)
            .toList()
          ..sort(
            (a, b) => (int.tryParse('${a['position'] ?? 0}') ?? 0).compareTo(
              int.tryParse('${b['position'] ?? 0}') ?? 0,
            ),
          );
    if (sources.isNotEmpty) return sources;
  }
  return [
    for (final source in productImageSources(product, fallback: fallback))
      {'type': 'image', 'url': source},
  ];
}

int productVideoCount(Map<String, dynamic> product) => productMediaSources(
  product,
  fallback: '',
).where((item) => item['type'] == 'video').length;
