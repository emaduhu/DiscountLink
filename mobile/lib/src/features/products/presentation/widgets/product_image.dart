part of '../../../../../main.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.source, this.fit});
  final String source;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        fit: fit ?? BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, size: 48),
      );
    }
    final filePath = source.startsWith('file://')
        ? Uri.parse(source).toFilePath()
        : source;
    final file = File(filePath);
    if (filePath.startsWith('/') && file.existsSync()) {
      return Image.file(
        file,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, size: 48),
      );
    }
    return Image.asset(
      source,
      fit: fit ?? BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, size: 48),
    );
  }
}
