part of '../../../../../main.dart';

class ProductMediaCarousel extends StatefulWidget {
  const ProductMediaCarousel({super.key, required this.media});

  final List<Map<String, dynamic>> media;

  @override
  State<ProductMediaCarousel> createState() => _ProductMediaCarouselState();
}
