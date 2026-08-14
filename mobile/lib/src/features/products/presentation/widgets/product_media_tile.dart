part of '../../../../../main.dart';

class ProductMediaTile extends StatefulWidget {
  const ProductMediaTile({
    super.key,
    required this.media,
    required this.active,
    this.fit = BoxFit.contain,
  });

  final Map<String, dynamic> media;
  final bool active;
  final BoxFit fit;

  @override
  State<ProductMediaTile> createState() => _ProductMediaTileState();
}
