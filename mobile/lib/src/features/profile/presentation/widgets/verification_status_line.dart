part of '../../../../../main.dart';

class VerificationStatusLine extends StatelessWidget {
  const VerificationStatusLine({
    super.key,
    required this.sent,
    required this.destination,
    required this.pendingText,
    this.visibleCode,
  });

  final bool sent;
  final String destination;
  final String pendingText;
  final String? visibleCode;

  @override
  Widget build(BuildContext context) {
    final code = visibleCode;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sent ? 'Code sent to $destination' : pendingText,
              style: const TextStyle(color: kTextColor, fontSize: 12),
            ),
            if (code != null && code.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.key_outlined,
                    size: 16,
                    color: kPrimaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Code: $code',
                    style: const TextStyle(
                      color: kPrimaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
