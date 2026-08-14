part of '../../../main.dart';

class ImageSearchPreview extends StatelessWidget {
  const ImageSearchPreview({
    super.key,
    required this.image,
    required this.active,
    required this.searching,
    required this.onPick,
    required this.onSearch,
    required this.onClear,
    this.message,
  });

  final XFile? image;
  final bool active;
  final bool searching;
  final String? message;
  final Future<void> Function() onPick;
  final Future<void> Function() onSearch;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final selectedImage = image;
    return SurfacePanel(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: selectedImage == null
                ? Container(
                    width: 82,
                    height: 82,
                    color: kPrimaryLightColor,
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: kPrimaryColor,
                      size: 32,
                    ),
                  )
                : Image.file(
                    File(selectedImage.path),
                    width: 82,
                    height: 82,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  searching
                      ? tx('Matching uploaded image', 'Inalinganisha picha')
                      : selectedImage == null
                      ? tx('Upload product photo', 'Pakia picha ya bidhaa')
                      : active
                      ? tx('Visual results ready', 'Matokeo ya picha tayari')
                      : tx('Ready to match image', 'Tayari kulinganisha picha'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message ??
                      tx(
                        'Choose a clear product photo. Matching compares images, not product names.',
                        'Chagua picha iliyo wazi. Ulinganishaji hutumia picha, si majina ya bidhaa.',
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextColor, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: searching ? null : onPick,
                      icon: Icon(
                        selectedImage == null
                            ? Icons.upload_file
                            : Icons.swap_horiz,
                      ),
                      label: Text(
                        selectedImage == null
                            ? tx('Upload', 'Pakia')
                            : tx('Replace', 'Badilisha'),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: selectedImage == null || searching
                          ? null
                          : onSearch,
                      icon: searching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        searching
                            ? tx('Matching...', 'Inatafuta...')
                            : tx('Find matches', 'Tafuta zinazofanana'),
                      ),
                    ),
                    if (selectedImage != null || active)
                      TextButton(
                        onPressed: searching ? null : onClear,
                        child: Text(tx('Clear', 'Futa')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
