part of '../../../../../main.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.onOfferTap,
  });
  final Map<String, dynamic> message;
  final bool mine;
  final ValueChanged<String> onOfferTap;

  @override
  Widget build(BuildContext context) {
    final body = '${message['body'] ?? ''}';
    final token = discountOfferToken(body);
    final time = chatMessageTime(message['created_at']);
    final status = chatDeliveryStatus(message, mine);
    final metadata = [
      if (time.isNotEmpty) time,
      if (status.isNotEmpty) status,
    ].join(' · ');
    final dark = appIsDark(context);
    final bubbleColor = mine
        ? dark
              ? const Color(0xff294536)
              : const Color(0xffdcf8c6)
        : appSurfaceColor(context);
    final bubbleTextColor = mine
        ? dark
              ? const Color(0xffe4f4e9)
              : Colors.black87
        : appForegroundColor(context);
    final metadataColor = mine
        ? dark
              ? const Color(0xffa6c9b0)
              : const Color(0xff5f7f4a)
        : appMutedTextColor(context).withValues(alpha: 0.88);
    final content = token == null
        ? Text(body)
        : InkWell(
            onTap: () => onOfferTap(token),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_offer_outlined,
                      size: 18,
                      color: kPrimaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tx('Discount offer', 'Ofa ya punguzo'),
                      style: const TextStyle(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(body.split('\n').first),
                const SizedBox(height: 6),
                Text(
                  tx('Tap to open in app', 'Bonyeza kufungua kwenye app'),
                  style: TextStyle(
                    color: appMutedTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: responsiveMaxWidth(context, kResponsiveChatMaxWidth) * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 6),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: appShadowColor(context, lightAlpha: 0.05, darkAlpha: 0.24),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DefaultTextStyle.merge(
              style: TextStyle(color: bubbleTextColor),
              child: content,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (metadata.isNotEmpty)
                    Text(
                      metadata,
                      style: TextStyle(
                        color: metadataColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (metadata.isNotEmpty) const SizedBox(width: 6),
                  Tooltip(
                    message: tx('Copy message', 'Nakili ujumbe'),
                    child: InkResponse(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: body));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tx('Message copied.', 'Ujumbe umenakiliwa.'),
                            ),
                          ),
                        );
                      },
                      radius: 18,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: metadataColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
