part of '../../../../../main.dart';

class _BuyerPageState extends State<BuyerPage> {
  final search = TextEditingController();
  List products = [];
  List cart = [];
  XFile? pickedImage;
  String? selectedCategory;
  String? imageSearchMessage;
  List<String> shopCategories = defaultShopCategories;
  final money = NumberFormat('#,##0.00');
  bool loadingProducts = true;
  bool loadingCart = true;
  bool imageSearchActive = false;
  bool searchingImage = false;
  bool loadingMoreProducts = false;
  int productPage = 1;
  int? productTotal;
  bool productHasMore = false;

  @override
  void initState() {
    super.initState();
    loadCategories();
    load();
  }

  Future<void> loadCategories() async {
    try {
      final r = await widget.client.get('/shop-categories');
      final next = ((r['categories'] as List?) ?? [])
          .map((category) => '$category'.trim())
          .where((category) => category.isNotEmpty)
          .toList();
      if (next.isNotEmpty && mounted) setState(() => shopCategories = next);
    } catch (_) {}
  }

  Future<void> load({bool append = false}) async {
    setState(() {
      if (append) {
        loadingMoreProducts = true;
      } else {
        loadingProducts = true;
        loadingCart = true;
        productPage = 1;
      }
    });
    final page = append ? productPage + 1 : 1;
    final query = <String, String>{'page': '$page', 'per_page': '20'};
    if (search.text.trim().isNotEmpty) query['q'] = search.text.trim();
    if (selectedCategory != null) query['category'] = selectedCategory!;
    try {
      final r = await widget.client.get('/products', query);
      final c = append ? null : await widget.client.get('/cart');
      final productResponse = r['products'];
      final nextProducts = responseItems(productResponse);
      if (!mounted) return;
      setState(() {
        products = append ? [...products, ...nextProducts] : nextProducts;
        productPage = page;
        productTotal = responseTotal(productResponse);
        productHasMore = responseHasMore(productResponse);
        if (c != null) cart = c['items'] as List;
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          loadingProducts = false;
          loadingCart = false;
          loadingMoreProducts = false;
        });
      }
    }
  }

  Future<void> loadCartCount() async {
    setState(() => loadingCart = true);
    try {
      final c = await widget.client.get('/cart');
      if (!mounted) return;
      setState(() => cart = c['items'] as List);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loadingCart = false);
    }
  }

  Future<void> imageSearchRun() async {
    final image = pickedImage;
    if (image == null) {
      throw Exception(tx('Upload an image first.', 'Pakia picha kwanza.'));
    }
    setState(() {
      loadingProducts = true;
      searchingImage = true;
      imageSearchMessage = tx(
        'Matching product images...',
        'Inalinganisha picha za bidhaa...',
      );
    });
    try {
      final r = await widget.client.postMultipart(
        '/products/image-search',
        fields: const {},
        file: File(image.path),
      );
      if (!mounted) return;
      setState(() {
        products = responseItems(r['products']);
        productTotal = products.length;
        productHasMore = false;
        imageSearchActive = true;
        imageSearchMessage = '${r['message'] ?? 'Image search complete.'}';
        selectedCategory = null;
        search.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(imageSearchMessage!)));
    } catch (error) {
      if (mounted) {
        setState(() => imageSearchMessage = '$error');
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingProducts = false;
          searchingImage = false;
        });
      }
    }
  }

  Future<void> pickSearchImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return;
    if (!mounted) return;
    setState(() {
      pickedImage = image;
      imageSearchMessage = tx(
        'Image ready. Tap Find matches to compare product photos.',
        'Picha iko tayari. Bonyeza Tafuta zinazofanana kulinganisha picha za bidhaa.',
      );
    });
  }

  Future<void> clearImageSearch() async {
    setState(() {
      pickedImage = null;
      imageSearchActive = false;
      imageSearchMessage = null;
    });
    await load();
  }

  Future<void> startChat(Map<String, dynamic> product) async {
    final sellerId = product['seller_id'];
    if (sellerId == null) {
      throw Exception('Seller contact is not available for this product.');
    }
    final r = await widget.client.post('/conversations', {
      'user_id': sellerId,
      'product_id': product['id'],
    });
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(
          client: widget.client,
          user: widget.user,
          conversation: r['conversation'] as Map<String, dynamic>,
        ),
      ),
    );
  }

  Future<void> shareProductDownload(Map<String, dynamic> product) async {
    final productName = '${product['name'] ?? 'this product'}'.trim();
    final shopName = '${product['shop']?['name'] ?? ''}'.trim();
    final total = productTotalPrice(product);
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

  Future<void> openCartPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CartPage(
          client: widget.client,
          user: widget.user,
          onUserChanged: widget.onUserChanged,
        ),
      ),
    );
    await loadCartCount();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ResponsiveListView(
        maxWidth: kResponsiveWideContentMaxWidth,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          MarketplaceHeader(
            search: search,
            onSearch: load,
            cartCount: cart.length,
            cartLoading: loadingCart,
            onCart: openCartPage,
          ),
          const SizedBox(height: 18),
          const DealsBanner(),
          const SizedBox(height: 18),
          SectionTitle(
            title: tx('Search by image', 'Tafuta kwa picha'),
            action: imageSearchActive ? tx('Clear', 'Futa') : null,
            onAction: imageSearchActive ? clearImageSearch : null,
          ),
          const SizedBox(height: 10),
          ImageSearchPreview(
            image: pickedImage,
            active: imageSearchActive,
            searching: searchingImage,
            message: imageSearchMessage,
            onPick: pickSearchImage,
            onSearch: imageSearchRun,
            onClear: clearImageSearch,
          ),
          const SizedBox(height: 18),
          SectionTitle(title: tx('Categories', 'Makundi')),
          const SizedBox(height: 10),
          CategoryStrip(
            categories: categoryViewsFromNames(shopCategories),
            onSelected: (name) {
              selectedCategory = name;
              search.clear();
              load();
            },
          ),
          const SizedBox(height: 18),
          SectionTitle(
            title: imageSearchActive
                ? tx('Visual matches', 'Bidhaa zinazofanana')
                : tx('Popular products', 'Bidhaa maarufu'),
            action: imageSearchActive
                ? tx('Clear', 'Futa')
                : tx('Refresh', 'Onyesha upya'),
            onAction: imageSearchActive ? clearImageSearch : load,
          ),
          if (!loadingProducts && productTotal != null) ...[
            const SizedBox(height: 4),
            Text(
              tx(
                'Showing ${products.length} of $productTotal products',
                'Inaonyesha ${products.length} kati ya bidhaa $productTotal',
              ),
              style: const TextStyle(color: kTextColor, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          if (loadingProducts)
            const ListLoadingIndicator()
          else if (products.isEmpty)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: tx('No products found', 'Hakuna bidhaa zilizopatikana'),
              subtitle: tx(
                'Try refreshing or using a different search term.',
                'Jaribu kuonyesha upya au kutumia neno jingine.',
              ),
            )
          else
            GridView.builder(
              itemCount: products.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: responsiveProductGridColumns(context),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: responsiveProductGridAspectRatio(context),
              ),
              itemBuilder: (context, index) {
                final product = products[index] as Map<String, dynamic>;
                return ProductDealCard(
                  product: product,
                  money: money,
                  imageAsset: productImageSource(
                    product,
                    fallback: index.isEven
                        ? 'assets/images/product_headset.png'
                        : 'assets/images/product_popular_1.png',
                  ),
                  onAdd: () async {
                    await widget.client.post('/cart/${product['id']}', {
                      'quantity': 1,
                    });
                    await loadCartCount();
                  },
                  onStartChat: () => startChat(product),
                  onShare: () => shareProductDownload(product),
                  onRate: (rating) async {
                    await widget.client.post(
                      '/products/${product['id']}/rating',
                      {'rating': rating},
                    );
                    await load();
                  },
                );
              },
            ),
          if (!loadingProducts && productHasMore && !imageSearchActive) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loadingMoreProducts ? null : () => load(append: true),
              icon: loadingMoreProducts
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(
                loadingMoreProducts
                    ? tx('Loading...', 'Inapakia...')
                    : tx('Load more', 'Pakia zaidi'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
