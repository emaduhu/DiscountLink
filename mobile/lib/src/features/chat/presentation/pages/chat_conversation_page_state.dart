part of '../../../../../main.dart';

class _ChatConversationPageState extends State<ChatConversationPage> {
  final message = TextEditingController();
  final offerPrice = TextEditingController();
  final reportDetails = TextEditingController();
  late Map<String, dynamic> conversation;
  List messages = [];
  bool loading = true;
  bool sendingOffer = false;
  bool moderating = false;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    conversation = Map<String, dynamic>.from(widget.conversation);
    load();
    refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => load());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    message.dispose();
    offerPrice.dispose();
    reportDetails.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final r = await widget.client.get(
      '/conversations/${conversation['id']}/messages',
    );
    if (!mounted) return;
    setState(() {
      final loadedConversation = r['conversation'];
      if (loadedConversation is Map) {
        conversation = Map<String, dynamic>.from(loadedConversation);
      }
      messages = responseItems(r['messages']);
      loading = false;
    });
  }

  Future<void> send() async {
    final body = message.text.trim();
    if (body.isEmpty) return;
    message.clear();
    await widget.client.post('/conversations/${conversation['id']}/messages', {
      'body': body,
    });
    await load();
  }

  bool get isBlocked => conversation['blocked_at'] != null;

  bool get blockedByMe => conversation['blocked_by_id'] == widget.user['id'];

  Future<void> blockChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block chat?'),
        content: const Text(
          'You will stop new messages and discount offers in this chat until you unblock it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => moderating = true);
    try {
      final r = await widget.client.post(
        '/conversations/${conversation['id']}/block',
        {'reason': 'Blocked from app chat.'},
      );
      if (!mounted) return;
      setState(() {
        conversation = Map<String, dynamic>.from(r['conversation'] as Map);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat blocked.')));
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => moderating = false);
    }
  }

  Future<void> unblockChat() async {
    setState(() => moderating = true);
    try {
      final r = await widget.client.post(
        '/conversations/${conversation['id']}/unblock',
        {},
      );
      if (!mounted) return;
      setState(() {
        conversation = Map<String, dynamic>.from(r['conversation'] as Map);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat unblocked.')));
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => moderating = false);
    }
  }

  Future<void> reportChat() async {
    reportDetails.clear();
    String reason = 'Harassment or abuse';
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: ResponsiveCenter(
              maxWidth: kResponsiveSheetMaxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Report chat',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Harassment or abuse',
                        child: Text('Harassment or abuse'),
                      ),
                      DropdownMenuItem(
                        value: 'Fraud or scam',
                        child: Text('Fraud or scam'),
                      ),
                      DropdownMenuItem(
                        value: 'Unsafe product or request',
                        child: Text('Unsafe product or request'),
                      ),
                      DropdownMenuItem(value: 'Spam', child: Text('Spam')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => reason = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reportDetails,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Details',
                      hintText: 'Add context for the admin team',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Submit report'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (submitted != true) return;
    setState(() => moderating = true);
    try {
      await widget.client.post('/conversations/${conversation['id']}/report', {
        'reason': reason,
        'details': reportDetails.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted.')));
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => moderating = false);
    }
  }

  Future<void> openDiscountOffer(String token) async {
    try {
      final r = await widget.client.get('/discount-links/$token');
      if (!mounted) return;
      await showDiscountOfferSheet(
        r['discount_link'] as Map<String, dynamic>,
        r['is_valid'] == true,
      );
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> showDiscountOfferSheet(
    Map<String, dynamic> offer,
    bool isValid,
  ) async {
    final product = offer['product'] as Map<String, dynamic>;
    final money = NumberFormat('#,##0.00');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final price = num.tryParse('${offer['discount_price']}') ?? 0;
        final original = num.tryParse('${product['price']}') ?? 0;
        final delivery = num.tryParse('${product['delivery_price']}') ?? 0;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ResponsiveCenter(
              maxWidth: kResponsiveSheetMaxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: ProductImage(
                            source: productImageSource(
                              product,
                              fallback: 'assets/images/product_popular_1.png',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              product['shop']?['name'] ?? '',
                              style: const TextStyle(color: kTextColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Offer price: TZS ${money.format(price)}',
                    style: const TextStyle(
                      color: kPrimaryColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  if (original > price)
                    Text(
                      'Original: TZS ${money.format(original)}',
                      style: const TextStyle(
                        color: kTextColor,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    'Delivery: TZS ${money.format(delivery)}',
                    style: const TextStyle(color: kTextColor),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: isValid
                        ? () async {
                            await widget.client.post(
                              '/discount-links/${offer['token']}/cart',
                              {'quantity': 1},
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Discount offer added to cart.'),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(
                      isValid ? 'Add offer to cart' : 'Offer expired',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> showCreateOfferDialog() async {
    offerPrice.clear();
    final product = conversation['product'] as Map<String, dynamic>?;
    if (product == null) return;
    final money = NumberFormat('#,##0.00');
    final productName = product['name'] ?? 'this product';
    final original = num.tryParse('${product['price']}') ?? 0;
    final currentDiscount = num.tryParse('${product['discount_price']}');
    final delivery = num.tryParse('${product['delivery_price']}') ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: ResponsiveCenter(
            maxWidth: kResponsiveSheetMaxWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height * 0.42,
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 76,
                          height: 76,
                          child: ProductImage(
                            source: productImageSource(
                              product,
                              fallback: 'assets/images/product_popular_1.png',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Send discount offer',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: kSurfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _OfferPriceRow(
                            label: 'Original price',
                            value: 'TZS ${money.format(original)}',
                            strong: true,
                          ),
                          if (currentDiscount != null) ...[
                            const Divider(height: 18),
                            _OfferPriceRow(
                              label: 'Current discount price',
                              value: 'TZS ${money.format(currentDiscount)}',
                            ),
                          ],
                          const Divider(height: 18),
                          _OfferPriceRow(
                            label: 'Delivery price',
                            value: 'TZS ${money.format(delivery)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: offerPrice,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Negotiated product price',
                      prefixText: 'TZS ',
                      helperText:
                          'Enter a price lower than the original price.',
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: sendingOffer
                              ? null
                              : () async {
                                  final price = offerPrice.text.trim();
                                  if (price.isEmpty) return;
                                  setState(() => sendingOffer = true);
                                  try {
                                    await widget.client.post(
                                      '/conversations/${conversation['id']}/discount-links',
                                      {'discount_price': price},
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    await load();
                                  } catch (error) {
                                    if (context.mounted) {
                                      showError(context, error);
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => sendingOffer = false);
                                    }
                                  }
                                },
                          icon: sendingOffer
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.local_offer_outlined),
                          label: Text(
                            sendingOffer ? 'Sending...' : 'Send offer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final other = conversationOther(conversation, widget.user['id']);
    final title =
        other?['name'] ??
        '${tx('Conversation', 'Mazungumzo')} #${conversation['id']}';
    final role = other?['role'];
    final product = conversation['product'] as Map<String, dynamic>?;
    final canSendOffer =
        widget.user['role'] == 'seller' && product != null && !isBlocked;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: kPrimaryLightColor,
              child: Text(
                initials(title),
                style: const TextStyle(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (role != null)
                    Text(
                      role,
                      style: const TextStyle(fontSize: 12, color: kTextColor),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            enabled: !moderating,
            onSelected: (value) {
              if (value == 'report') reportChat();
              if (value == 'block') blockChat();
              if (value == 'unblock') unblockChat();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Report chat'),
                ),
              ),
              if (isBlocked && blockedByMe)
                const PopupMenuItem(
                  value: 'unblock',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.lock_open_outlined),
                    title: Text('Unblock chat'),
                  ),
                )
              else if (!isBlocked)
                const PopupMenuItem(
                  value: 'block',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.block),
                    title: Text('Block chat'),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (isBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: const Color(0xfffff1f2),
              child: Row(
                children: [
                  const Icon(Icons.block, color: Color(0xffb91c1c)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      blockedByMe
                          ? 'You blocked this chat. Unblock it to send messages.'
                          : 'This chat is blocked. New messages are disabled.',
                      style: const TextStyle(
                        color: Color(0xff7f1d1d),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (product != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: kPrimaryLightColor,
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: kPrimaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (canSendOffer)
                    TextButton.icon(
                      onPressed: showCreateOfferDialog,
                      icon: const Icon(Icons.sell_outlined),
                      label: const Text('Offer'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? Center(
                    child: Text(
                      tx('No messages yet.', 'Bado hakuna ujumbe.'),
                      style: TextStyle(color: appMutedTextColor(context)),
                    ),
                  )
                : ResponsiveCenter(
                    maxWidth: kResponsiveChatMaxWidth,
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final item = messages[index] as Map<String, dynamic>;
                        final mine = item['sender_id'] == widget.user['id'];
                        return ChatBubble(
                          message: item,
                          mine: mine,
                          onOfferTap: openDiscountOffer,
                        );
                      },
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              color: appSurfaceColor(context),
              child: ResponsiveCenter(
                maxWidth: kResponsiveChatMaxWidth,
                child: isBlocked
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Messaging is disabled for this chat.',
                              style: TextStyle(
                                color: appMutedTextColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (blockedByMe)
                            TextButton.icon(
                              onPressed: moderating ? null : unblockChat,
                              icon: const Icon(Icons.lock_open_outlined),
                              label: const Text('Unblock'),
                            ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: message,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => send(),
                              decoration: InputDecoration(
                                hintText: tx('Message', 'Ujumbe'),
                                filled: true,
                                fillColor: appSubtleSurfaceColor(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: send,
                            icon: const Icon(Icons.send),
                            style: IconButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              fixedSize: const Size(48, 48),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
