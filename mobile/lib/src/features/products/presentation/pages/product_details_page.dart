part of '../../../../../main.dart';

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({
    super.key,
    required this.client,
    required this.user,
    required this.productId,
  });

  final ApiClient client;
  final Map<String, dynamic> user;
  final int productId;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final money = NumberFormat('#,##0.00');
  Map<String, dynamic>? product;
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadProduct();
  }

  Future<void> loadProduct() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final response = await widget.client.get('/products/${widget.productId}');
      final loadedProduct = response['product'];
      if (loadedProduct is! Map) {
        throw Exception('Product details are not available.');
      }
      if (!mounted) return;
      setState(() => product = Map<String, dynamic>.from(loadedProduct));
    } catch (error) {
      if (!mounted) return;
      setState(
        () => errorMessage = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addToCart() async {
    final currentProduct = product;
    if (currentProduct == null) return;
    await widget.client.post('/cart/${currentProduct['id']}', {'quantity': 1});
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tx('Product added to cart.', 'Bidhaa imeongezwa kikapuni.'),
          ),
        ),
      );
  }

  Future<void> startChat() async {
    final currentProduct = product;
    if (currentProduct == null) return;
    final sellerId = currentProduct['seller_id'];
    if (sellerId == null) {
      throw Exception('Seller contact is not available for this product.');
    }
    final response = await widget.client.post('/conversations', {
      'user_id': sellerId,
      'product_id': currentProduct['id'],
    });
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(
          client: widget.client,
          user: widget.user,
          conversation: response['conversation'] as Map<String, dynamic>,
        ),
      ),
    );
  }

  Future<void> shareProductDownload() async {
    final currentProduct = product;
    if (currentProduct == null) return;
    final productName = '${currentProduct['name'] ?? 'this product'}'.trim();
    final shopName = '${currentProduct['shop']?['name'] ?? ''}'.trim();
    final total = productTotalPrice(currentProduct);
    final priceLine = '\n${tx('Price', 'Bei')}: TZS ${money.format(total)}';
    final shopLine = shopName.isEmpty
        ? ''
        : '\n${tx('Shop', 'Duka')}: $shopName';
    final message = tx(
      'I found $productName on Discount Link.$shopLine$priceLine\n\nDownload the app to view and buy this product:\nAndroid: $playStoreUrl\niPhone: $appStoreUrl',
      'Nimepata $productName kwenye Discount Link.$shopLine$priceLine\n\nPakua app kuangalia na kununua bidhaa hii:\nAndroid: $playStoreUrl\niPhone: $appStoreUrl',
    );

    await SharePlus.instance.share(
      ShareParams(text: message, subject: 'View $productName on Discount Link'),
    );
  }

  Future<void> rateProduct(int rating) async {
    final currentProduct = product;
    if (currentProduct == null) return;
    final response = await widget.client.post(
      '/products/${currentProduct['id']}/rating',
      {'rating': rating},
    );
    final updatedProduct = response['product'];
    if (!mounted || updatedProduct is! Map) return;
    setState(() => product = Map<String, dynamic>.from(updatedProduct));
  }

  @override
  Widget build(BuildContext context) {
    final currentProduct = product;
    final title = currentProduct == null
        ? tx('Product', 'Bidhaa')
        : '${currentProduct['name'] ?? tx('Product', 'Bidhaa')}';
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1)),
      body: RefreshIndicator(
        onRefresh: loadProduct,
        child: ResponsiveListView(
          maxWidth: kResponsiveContentMaxWidth,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null || currentProduct == null)
              EmptyState(
                icon: Icons.inventory_2_outlined,
                title: tx('Product unavailable', 'Bidhaa haipatikani'),
                subtitle:
                    errorMessage ?? 'This product is no longer available.',
              )
            else
              _ProductDetailsContent(
                product: currentProduct,
                user: widget.user,
                money: money,
                onAddToCart: addToCart,
                onStartChat: startChat,
                onShare: shareProductDownload,
                onRate: rateProduct,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailsContent extends StatelessWidget {
  const _ProductDetailsContent({
    required this.product,
    required this.user,
    required this.money,
    required this.onAddToCart,
    required this.onStartChat,
    required this.onShare,
    required this.onRate,
  });

  final Map<String, dynamic> product;
  final Map<String, dynamic> user;
  final NumberFormat money;
  final Future<void> Function() onAddToCart;
  final Future<void> Function() onStartChat;
  final Future<void> Function() onShare;
  final Future<void> Function(int rating) onRate;

  @override
  Widget build(BuildContext context) {
    final media = productMediaSources(
      product,
      fallback: productImageSource(
        product,
        fallback: 'assets/images/product_headset.png',
      ),
    );
    final shop = product['shop'];
    final matchPercent = productImageMatchPercent(product);
    final canBuy = user['role'] == 'buyer' || user['role'] == 'seller';
    final sellerId = '${product['seller_id'] ?? ''}';
    final currentUserId = '${user['id'] ?? ''}';
    final canStartChat = sellerId.isNotEmpty && sellerId != currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfacePanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductMediaCarousel(media: media),
              const SizedBox(height: 14),
              Text(
                '${product['name'] ?? tx('Product', 'Bidhaa')}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: appTitleColor(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${product['description'] ?? ''}',
                style: TextStyle(
                  color: appMutedTextColor(context),
                  height: 1.35,
                ),
              ),
              if (shop is Map) ...[
                const SizedBox(height: 10),
                StatusPill(
                  label:
                      '${shop['name'] ?? tx('Shop', 'Duka')} · ${shop['is_open'] == true ? tx('Open now', 'Limefunguliwa') : tx('Closed now', 'Limefungwa')}',
                  color: shop['is_open'] == true
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ],
              if (matchPercent != null) ...[
                const SizedBox(height: 8),
                StatusPill(
                  label: '$matchPercent% visual match',
                  color: appIsDark(context)
                      ? kDarkMutedTextColor
                      : Colors.black87,
                ),
              ],
              const SizedBox(height: 12),
              RatingSummary(product: product),
              if (canBuy) ...[
                const SizedBox(height: 8),
                RatingPicker(onRate: onRate),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          padding: const EdgeInsets.all(14),
          child: ProductPriceBreakdown(product: product, money: money),
        ),
        const SizedBox(height: 16),
        if (canBuy)
          FilledButton.icon(
            onPressed: onAddToCart,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(tx('Add to cart', 'Weka kikapuni')),
          ),
        if (canBuy) const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onShare,
          icon: const Icon(Icons.ios_share_outlined),
          label: Text(tx('Share download link', 'Shiriki link ya kupakua')),
        ),
        if (canStartChat) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onStartChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(tx('Start chat with seller', 'Anza soga na muuzaji')),
          ),
        ],
      ],
    );
  }
}
