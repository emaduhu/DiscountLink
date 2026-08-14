part of '../../../../../main.dart';

class _SellerPaginationControls extends StatelessWidget {
  const _SellerPaginationControls({
    required this.label,
    required this.previousKey,
    required this.nextKey,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final Key previousKey;
  final Key nextKey;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kTextColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: previousKey,
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: nextKey,
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
