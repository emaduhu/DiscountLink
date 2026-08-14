part of '../../../../../main.dart';

class _SellerPageState extends State<SellerPage> {
  static const int campaignPageSize = 5;
  static const int productPageSize = 5;

  final shopName = TextEditingController();
  final address = TextEditingController();
  final shopRegistrationPhone = TextEditingController();
  final productName = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final discount = TextEditingController();
  final delivery = TextEditingController();
  final stock = TextEditingController(text: '10');
  final delivererName = TextEditingController();
  final delivererPhone = TextEditingController();
  final campaignPhone = TextEditingController();
  final money = NumberFormat('#,##0.00');
  final campaignResendPhones = <int, TextEditingController>{};
  final shopResendPhones = <int, TextEditingController>{};
  final selectedCategories = <String>{'Electronics'};
  List<String> shopCategories = defaultShopCategories;
  final picker = ImagePicker();
  List<XFile> selectedProductImages = [];
  List<XFile> selectedProductVideos = [];
  List shops = [];
  List campaigns = [];
  Map<String, dynamic> campaignPricing = {};
  Map<String, dynamic> registrationFee = {
    'amount': 0,
    'currency': 'TZS',
    'enabled': false,
  };
  List delivererInvitations = [];
  int? selectedShopId;
  int? editingShopId;
  int? editingProductId;
  _ShopEditDraft? shopDraft;
  _ProductEditDraft? productDraft;
  List<XFile> replacementProductImages = [];
  List<XFile> replacementProductVideos = [];
  bool clearReplacementProductVideos = false;
  TimeOfDay openingTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay closingTime = const TimeOfDay(hour: 20, minute: 0);
  int? campaignProductId;
  String campaignChannel = 'fcm';
  bool loadingShops = true;
  bool loadingMoreShops = false;
  bool invitingDeliverer = false;
  bool loadingCampaigns = true;
  bool creatingCampaign = false;
  bool creatingShop = false;
  bool publishingProduct = false;
  int? resendingCampaignPaymentId;
  int? resendingShopPaymentId;
  int? editingCampaignPaymentId;
  int? editingShopPaymentId;
  int? deletingShopId;
  String? campaignResendPhoneError;
  String? shopResendPhoneError;
  int shopPage = 1;
  int? shopTotal;
  bool shopHasMore = false;
  int campaignPage = 1;
  int? campaignTotal;
  bool campaignHasMore = false;
  final Map<int, int> productPageByShop = {};
  final sellerOpenShopKey = GlobalKey();
  final sellerCampaignsKey = GlobalKey();
  final sellerDelivererKey = GlobalKey();
  final sellerListProductKey = GlobalKey();
  final sellerProductsKey = GlobalKey();

  bool get sellerUssdBusy =>
      creatingCampaign ||
      creatingShop ||
      resendingCampaignPaymentId != null ||
      resendingShopPaymentId != null;

  @override
  void initState() {
    super.initState();
    address.text = widget.user['address'] ?? '';
    shopRegistrationPhone.text = widget.user['phone'] ?? '';
    campaignPhone.text = widget.user['phone'] ?? '';
    loadCategories();
    load();
    loadCampaigns();
  }

  Future<void> loadCategories() async {
    try {
      final r = await widget.client.get('/shop-categories');
      final next = ((r['categories'] as List?) ?? [])
          .map((category) => '$category'.trim())
          .where((category) => category.isNotEmpty)
          .toList();
      if (next.isEmpty || !mounted) return;
      setState(() {
        shopCategories = next;
        selectedCategories.removeWhere((category) => !next.contains(category));
        if (selectedCategories.isEmpty) selectedCategories.add(next.first);
      });
    } catch (_) {}
  }

  Future<void> load({bool append = false}) async {
    setState(() {
      if (append) {
        loadingMoreShops = true;
      } else {
        loadingShops = true;
      }
    });
    final page = append ? shopPage + 1 : 1;
    try {
      final r = await widget.client.get('/seller/shops', {
        'page': '$page',
        'per_page': '20',
      });
      final shopResponse = r['shops'];
      final nextShops = responseItems(shopResponse);
      if (!mounted) return;
      setState(() {
        shops = append ? [...shops, ...nextShops] : nextShops;
        shopPage = page;
        shopTotal = responseTotal(shopResponse);
        shopHasMore = responseHasMore(shopResponse);
        registrationFee =
            (r['registration_fee'] as Map?)?.cast<String, dynamic>() ??
            {'amount': 0, 'currency': 'TZS', 'enabled': false};
        delivererInvitations = (r['deliverer_invitations'] as List?) ?? [];
        if (shops.isNotEmpty) {
          selectedShopId ??= shops.first['id'] as int;
          if (!shops.any((shop) => shop['id'] == selectedShopId)) {
            selectedShopId = shops.first['id'] as int;
          }
        } else {
          selectedShopId = null;
        }
        clampProductPages();
        final products = sellerProducts();
        if (products.isNotEmpty) {
          campaignProductId ??= products.first['id'] as int?;
          if (!products.any((product) => product['id'] == campaignProductId)) {
            campaignProductId = products.first['id'] as int?;
          }
        } else {
          campaignProductId = null;
        }
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          loadingShops = false;
          loadingMoreShops = false;
        });
      }
    }
  }

  String apiTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  TimeOfDay parseApiTime(String? value, TimeOfDay fallback) {
    final parts = (value ?? '').split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> pickShopTime({required bool opening}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: opening ? openingTime : closingTime,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (opening) {
        openingTime = selected;
      } else {
        closingTime = selected;
      }
    });
  }

  Future<void> pickDraftShopTime({required bool opening}) async {
    final draft = shopDraft;
    if (draft == null) return;
    final current = parseApiTime(
      opening ? draft.openingTime : draft.closingTime,
      opening
          ? const TimeOfDay(hour: 8, minute: 0)
          : const TimeOfDay(hour: 20, minute: 0),
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (opening) {
        draft.openingTime = apiTime(selected);
      } else {
        draft.closingTime = apiTime(selected);
      }
    });
  }

  Widget compactScheduleButton({
    required Key key,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        key: key,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        icon: Icon(icon, size: 18),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
      ),
    );
  }

  Widget responsiveScheduleButtons({
    required Key openingKey,
    required Key closingKey,
    required VoidCallback onOpeningPressed,
    required VoidCallback onClosingPressed,
    required String openingLabel,
    required String closingLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: compactScheduleButton(
            key: openingKey,
            onPressed: onOpeningPressed,
            icon: Icons.storefront_outlined,
            label: openingLabel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: compactScheduleButton(
            key: closingKey,
            onPressed: onClosingPressed,
            icon: Icons.nightlight_outlined,
            label: closingLabel,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> sellerProducts() {
    return [
      for (final shop in shops)
        for (final product in ((shop['products'] as List?) ?? []))
          if (product is Map)
            Map<String, dynamic>.from(product)
              ..putIfAbsent('shop_name', () => shop['name']),
    ];
  }

  List<dynamic> productsForShop(dynamic shop) {
    if (shop is! Map) return const <dynamic>[];
    return (shop['products'] as List?) ?? const <dynamic>[];
  }

  int? idForShop(dynamic shop) {
    if (shop is! Map) return null;
    return int.tryParse('${shop['id'] ?? ''}');
  }

  int productPageCount(dynamic shop) {
    final count = productsForShop(shop).length;
    return count == 0 ? 1 : ((count - 1) ~/ productPageSize) + 1;
  }

  int productPageForShop(dynamic shop) {
    final shopId = idForShop(shop);
    var page = shopId == null ? 1 : (productPageByShop[shopId] ?? 1);
    final lastPage = productPageCount(shop);
    if (page < 1) page = 1;
    if (page > lastPage) page = lastPage;
    return page;
  }

  List<dynamic> visibleProductsForShop(dynamic shop) {
    final products = productsForShop(shop);
    final page = productPageForShop(shop);
    final start = (page - 1) * productPageSize;
    final end = start + productPageSize < products.length
        ? start + productPageSize
        : products.length;
    return products.sublist(start, end);
  }

  void clampProductPages() {
    final loadedShopIds = <int>{};
    for (final shop in shops) {
      final shopId = idForShop(shop);
      if (shopId == null) continue;
      loadedShopIds.add(shopId);
      productPageByShop[shopId] = productPageForShop(shop);
    }
    productPageByShop.removeWhere(
      (shopId, _) => !loadedShopIds.contains(shopId),
    );
  }

  void changeProductPage(dynamic shop, int requestedPage) {
    final shopId = idForShop(shop);
    if (shopId == null) return;
    var nextPage = requestedPage;
    final lastPage = productPageCount(shop);
    if (nextPage < 1) nextPage = 1;
    if (nextPage > lastPage) nextPage = lastPage;
    setState(() => productPageByShop[shopId] = nextPage);
  }

  String productPageLabel(dynamic shop) {
    final count = productsForShop(shop).length;
    final page = productPageForShop(shop);
    final first = count == 0 ? 0 : ((page - 1) * productPageSize) + 1;
    final last = count == 0
        ? 0
        : (first + productPageSize - 1 < count
              ? first + productPageSize - 1
              : count);
    return 'Showing $first–$last of $count products';
  }

  String campaignPageLabel() {
    final first = campaigns.isEmpty
        ? 0
        : ((campaignPage - 1) * campaignPageSize) + 1;
    final last = campaigns.isEmpty ? 0 : first + campaigns.length - 1;
    final total = campaignTotal;
    return total == null
        ? 'Showing $first–$last campaigns'
        : 'Showing $first–$last of $total campaigns';
  }

  Future<Map<String, dynamic>> fetchCampaignPage(int page) {
    return widget.client.get('/seller/campaigns', {
      'page': '$page',
      'per_page': '$campaignPageSize',
    });
  }

  Future<void> loadCampaigns({int page = 1}) async {
    var requestedPage = page < 1 ? 1 : page;
    setState(() {
      loadingCampaigns = true;
      campaignPricing = {};
    });
    try {
      var response = await fetchCampaignPage(requestedPage);
      var campaignResponse = response['campaigns'];
      if (campaignResponse is Map) {
        final parsedLastPage = int.tryParse(
          '${campaignResponse['last_page'] ?? ''}',
        );
        final lastPage = parsedLastPage != null && parsedLastPage > 0
            ? parsedLastPage
            : 1;
        if (requestedPage > lastPage) {
          requestedPage = lastPage;
          response = await fetchCampaignPage(requestedPage);
          campaignResponse = response['campaigns'];
        }
      }
      if (!mounted) return;
      setState(() {
        final returnedPage = campaignResponse is Map
            ? int.tryParse('${campaignResponse['current_page'] ?? ''}')
            : null;
        campaigns = responseItems(campaignResponse);
        campaignPage = returnedPage != null && returnedPage > 0
            ? returnedPage
            : requestedPage;
        campaignTotal = responseTotal(campaignResponse);
        campaignHasMore = responseHasMore(campaignResponse);
        campaignPricing =
            (response['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loadingCampaigns = false);
    }
  }

  Map<String, dynamic> selectedCampaignPricing() {
    return (campaignPricing[campaignChannel] as Map?)
            ?.cast<String, dynamic>() ??
        {};
  }

  bool campaignQuoteIsReady() {
    if (loadingCampaigns) return false;
    final pricing = selectedCampaignPricing();
    final unitPrice = num.tryParse('${pricing['unit_price'] ?? ''}');
    final recipientCount = int.tryParse(
      '${pricing['eligible_recipient_count'] ?? ''}',
    );
    final estimatedTotal = num.tryParse('${pricing['estimated_total'] ?? ''}');

    return unitPrice != null &&
        unitPrice >= 0 &&
        recipientCount != null &&
        recipientCount > 0 &&
        estimatedTotal != null &&
        estimatedTotal >= 0;
  }

  Future<void> createCampaign() async {
    if (sellerUssdBusy) return;
    final productId = campaignProductId;
    if (productId == null) {
      showError(context, Exception('Choose a product to promote.'));
      return;
    }
    if (!campaignQuoteIsReady()) {
      showError(
        context,
        Exception(
          loadingCampaigns
              ? 'Wait for the latest campaign price before continuing.'
              : 'A live campaign price and eligible audience are required. Refresh and try again.',
        ),
      );
      return;
    }
    final pricing = selectedCampaignPricing();
    final recipientCount = pricing['eligible_recipient_count'] ?? 0;
    final estimated = num.tryParse('${pricing['estimated_total'] ?? 0}') ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm product campaign'),
        content: Text(
          'DiscountLink will generate the campaign message and send it to $recipientCount eligible users through ${campaignChannel.toUpperCase()}.\n\nEstimated cost: TZS ${money.format(estimated)}. The final recipient count and price are locked when the campaign is created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(estimated > 0 ? 'Create and pay' : 'Create campaign'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (sellerUssdBusy) return;

    setState(() => creatingCampaign = true);
    try {
      final response = await widget.client.post('/seller/campaigns', {
        'product_id': productId,
        'channel': campaignChannel,
        if (campaignPhone.text.trim().isNotEmpty)
          'payment_phone': requireTwelveDigitPhone(campaignPhone.text),
      });
      await loadCampaigns(page: 1);
      if (!mounted) return;
      final payment = response['payment'] as Map?;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(payment == null ? 'Campaign queued' : 'Payment sent'),
          content: Text(
            '${response['message'] ?? 'Campaign created.'}'
            '${payment == null ? '' : '\n\nApprove the ClickPesa USSD request on ${payment['phone'] ?? campaignPhone.text}. The campaign starts only after payment is confirmed.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => creatingCampaign = false);
    }
  }

  TextEditingController campaignResendPhoneController(
    int paymentId,
    String initialPhone,
  ) {
    return campaignResendPhones.putIfAbsent(
      paymentId,
      () => TextEditingController(text: initialPhone),
    );
  }

  TextEditingController shopResendPhoneController(
    int paymentId,
    String initialPhone,
  ) {
    return shopResendPhones.putIfAbsent(
      paymentId,
      () => TextEditingController(text: initialPhone),
    );
  }

  void showCampaignResendPrompt(Map<String, dynamic> campaign) {
    if (sellerUssdBusy) return;
    final payment = (campaign['payment'] as Map?)?.cast<String, dynamic>();
    final paymentId = int.tryParse('${payment?['id'] ?? ''}');
    if (paymentId == null) return;
    final controller = campaignResendPhoneController(
      paymentId,
      '${payment?['phone'] ?? campaignPhone.text}',
    );
    controller.text = '${payment?['phone'] ?? campaignPhone.text}';
    setState(() {
      editingCampaignPaymentId = paymentId;
      editingShopPaymentId = null;
      campaignResendPhoneError = null;
      shopResendPhoneError = null;
    });
  }

  void hideCampaignResendPrompt() {
    if (resendingCampaignPaymentId != null) return;
    setState(() {
      editingCampaignPaymentId = null;
      campaignResendPhoneError = null;
    });
  }

  Future<void> resendCampaignPayment(Map<String, dynamic> campaign) async {
    if (sellerUssdBusy) return;
    final payment = (campaign['payment'] as Map?)?.cast<String, dynamic>();
    final paymentId = int.tryParse('${payment?['id'] ?? ''}');
    if (paymentId == null) return;
    final controller = campaignResendPhoneController(
      paymentId,
      '${payment?['phone'] ?? campaignPhone.text}',
    );
    late final String paymentPhone;
    try {
      paymentPhone = requireTwelveDigitPhone(controller.text);
    } catch (error) {
      setState(() {
        campaignResendPhoneError = error.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
      return;
    }
    campaignPhone.text = paymentPhone;
    setState(() => resendingCampaignPaymentId = paymentId);
    try {
      final response = await widget.client.post(
        '/seller/campaign-payments/$paymentId/ussd-push',
        {'payment_phone': paymentPhone},
      );
      if (!mounted) return;
      setState(() {
        editingCampaignPaymentId = null;
        campaignResendPhoneError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${response['message'] ?? 'Payment request sent.'}'),
        ),
      );
      await loadCampaigns(page: campaignPage);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted && resendingCampaignPaymentId == paymentId) {
        setState(() => resendingCampaignPaymentId = null);
      }
    }
  }

  Future<void> pickProductImages() async {
    final images = await picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;
    if (images.length != 3) {
      if (mounted) {
        showError(context, Exception('Choose exactly 3 product images.'));
      }
      return;
    }
    setState(() => selectedProductImages = images.take(3).toList());
  }

  Future<void> pickProductVideo() async {
    if (selectedProductVideos.length >= 2) return;
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (video == null || !mounted) return;
    setState(() => selectedProductVideos = [...selectedProductVideos, video]);
  }

  List<String> productImagePaths() {
    return selectedProductImages.map((image) => image.path).toList();
  }

  Future<void> publishProduct() async {
    if (publishingProduct) return;
    final targetShopId = selectedShopId;
    final targetShop = selectedShop();
    if (targetShopId == null || targetShop?['is_active'] != true) return;

    setState(() => publishingProduct = true);
    try {
      final images = productImagePaths();
      if (images.length != 3) {
        throw Exception('Choose exactly 3 product images from phone.');
      }
      await widget.client.postMultipartMedia(
        '/shops/$targetShopId/products',
        fields: {
          'name': productName.text,
          'description': description.text,
          'price': price.text,
          'discount_percent': discount.text,
          'delivery_price': delivery.text,
          'stock': stock.text,
        },
        images: selectedProductImages.map((image) => File(image.path)).toList(),
        videos: selectedProductVideos.map((video) => File(video.path)).toList(),
      );
      setState(() {
        selectedProductImages = [];
        selectedProductVideos = [];
        productPageByShop[targetShopId] = 1;
      });
      await load();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => publishingProduct = false);
    }
  }

  Map<String, dynamic>? selectedShop() {
    for (final shop in shops) {
      if (shop is Map<String, dynamic> && shop['id'] == selectedShopId) {
        return shop;
      }
    }
    return null;
  }

  double registrationFeeAmount() =>
      double.tryParse('${registrationFee['amount'] ?? 0}') ?? 0;

  bool registrationFeeEnabled() =>
      registrationFee['enabled'] == true || registrationFeeAmount() > 0;

  String shopRegistrationStatus(Map<String, dynamic> shop) {
    final status = '${shop['registration_fee_status'] ?? 'waived'}';
    if (shop['is_active'] == true && status == 'paid') {
      return 'Registration paid';
    }
    if (shop['is_active'] == true && status == 'waived') {
      return 'Registration fee waived';
    }
    if (status == 'processing') return 'Waiting for ClickPesa confirmation';
    if (status == 'failed') return 'Registration fee push failed';
    return 'Registration fee pending';
  }

  int? shopRegistrationPaymentId(Map<String, dynamic> shop) {
    final payment =
        shop['registration_fee_payment'] ?? shop['registrationFeePayment'];
    final value = payment is Map
        ? payment['id']
        : shop['registration_fee_payment_id'];
    return int.tryParse('${value ?? ''}');
  }

  bool canRetryShopRegistration(Map<String, dynamic> shop) {
    if (shop['is_active'] == true || shopRegistrationPaymentId(shop) == null) {
      return false;
    }
    return const {
      'pending',
      'processing',
      'failed',
      'payment_failed',
    }.contains('${shop['registration_fee_status'] ?? ''}');
  }

  void showShopRegistrationResendPrompt(Map<String, dynamic> shop) {
    if (sellerUssdBusy) return;
    final paymentId = shopRegistrationPaymentId(shop);
    if (paymentId == null) return;
    final payment =
        (shop['registration_fee_payment'] ?? shop['registrationFeePayment'])
            as Map?;
    final controller = shopResendPhoneController(
      paymentId,
      '${payment?['phone'] ?? shopRegistrationPhone.text}',
    );
    controller.text = '${payment?['phone'] ?? shopRegistrationPhone.text}';
    setState(() {
      editingCampaignPaymentId = null;
      editingShopPaymentId = paymentId;
      campaignResendPhoneError = null;
      shopResendPhoneError = null;
    });
  }

  void hideShopRegistrationResendPrompt() {
    if (resendingShopPaymentId != null) return;
    setState(() {
      editingShopPaymentId = null;
      shopResendPhoneError = null;
    });
  }

  Future<void> resendShopRegistrationPayment(Map<String, dynamic> shop) async {
    if (sellerUssdBusy) return;
    final paymentId = shopRegistrationPaymentId(shop);
    if (paymentId == null) return;
    final payment =
        (shop['registration_fee_payment'] ?? shop['registrationFeePayment'])
            as Map?;
    final controller = shopResendPhoneController(
      paymentId,
      '${payment?['phone'] ?? shopRegistrationPhone.text}',
    );
    late final String paymentPhone;
    try {
      paymentPhone = requireTwelveDigitPhone(controller.text);
    } catch (error) {
      setState(() {
        shopResendPhoneError = error.toString().replaceFirst('Exception: ', '');
      });
      return;
    }
    shopRegistrationPhone.text = paymentPhone;
    setState(() => resendingShopPaymentId = paymentId);
    try {
      final response = await widget.client.post(
        '/seller/shop-payments/$paymentId/ussd-push',
        {'registration_payment_phone': paymentPhone},
      );
      if (!mounted) return;
      setState(() {
        editingShopPaymentId = null;
        shopResendPhoneError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${response['message'] ?? 'Registration payment request sent.'}',
          ),
        ),
      );
      await load();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted && resendingShopPaymentId == paymentId) {
        setState(() => resendingShopPaymentId = null);
      }
    }
  }

  Future<void> deleteShop(Map<String, dynamic> shop) async {
    if (deletingShopId != null || sellerUssdBusy) return;
    final shopId = int.tryParse('${shop['id'] ?? ''}');
    if (shopId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete shop?'),
        content: Text(
          '${shop['name'] ?? 'This shop'} and its products will no longer be visible to buyers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete shop'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || deletingShopId != null) return;

    setState(() => deletingShopId = shopId);
    try {
      final response = await widget.client.delete('/shops/$shopId');
      if (!mounted) return;
      if (editingShopId == shopId) cancelShopEdit();
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${response['message'] ?? 'Shop deleted.'}')),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted && deletingShopId == shopId) {
        setState(() => deletingShopId = null);
      }
    }
  }

  Future<void> saveShop() async {
    if (sellerUssdBusy) return;
    setState(() => creatingShop = true);
    try {
      final registrationPaymentPhone = registrationFeeEnabled()
          ? requireTwelveDigitPhone(shopRegistrationPhone.text)
          : null;
      final r = await widget.client.post('/shops', {
        'name': shopName.text,
        'category': selectedCategories.first,
        'categories': selectedCategories.toList(),
        'address': address.text,
        'opening_time': apiTime(openingTime),
        'closing_time': apiTime(closingTime),
        'timezone': 'Africa/Dar_es_Salaam',
        if (registrationPaymentPhone != null)
          'registration_payment_phone': registrationPaymentPhone,
      });
      shopName.clear();
      await load();
      if (!mounted) return;
      final payment = r['payment'] as Map<String, dynamic>?;
      if (payment != null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Registration fee push sent'),
            content: Text(
              'Approve the ClickPesa USSD prompt on ${payment['phone'] ?? shopRegistrationPhone.text}.\n\n'
              'Amount: TZS ${money.format(double.tryParse('${payment['amount'] ?? registrationFeeAmount()}') ?? registrationFeeAmount())}\n'
              'Shop activates after payment confirmation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${r['message'] ?? 'Shop created.'}')),
        );
      }
    } catch (error) {
      if (mounted) showError(context, error);
      await load();
    } finally {
      if (mounted) setState(() => creatingShop = false);
    }
  }

  void startEditShop(Map<String, dynamic> shop) {
    shopDraft?.dispose();
    final categories = <String>{
      ...(((shop['categories'] as List?) ?? [shop['category']])
          .whereType<String>()),
    };
    if (categories.isEmpty) categories.add('Electronics');
    setState(() {
      editingShopId = shop['id'] as int?;
      shopDraft = _ShopEditDraft(
        name: shop['name'] ?? '',
        address: shop['address'] ?? '',
        categories: categories,
        openingTime: '${shop['opening_time'] ?? '08:00'}',
        closingTime: '${shop['closing_time'] ?? '20:00'}',
      );
    });
  }

  void startEditProduct(Map<String, dynamic> product) {
    productDraft?.dispose();
    setState(() {
      editingProductId = product['id'] as int?;
      replacementProductImages = [];
      replacementProductVideos = [];
      clearReplacementProductVideos = false;
      productDraft = _ProductEditDraft(product);
    });
  }

  void cancelShopEdit() {
    shopDraft?.dispose();
    setState(() {
      editingShopId = null;
      shopDraft = null;
    });
  }

  void cancelProductEdit() {
    productDraft?.dispose();
    setState(() {
      editingProductId = null;
      productDraft = null;
      replacementProductImages = [];
      replacementProductVideos = [];
      clearReplacementProductVideos = false;
    });
  }

  Future<void> saveShopEdit(Map<String, dynamic> shop) async {
    final draft = shopDraft;
    if (draft == null) return;
    try {
      await widget.client.put('/shops/${shop['id']}', {
        'name': draft.name.text.trim(),
        'category': draft.categories.first,
        'categories': draft.categories.toList(),
        'address': draft.address.text.trim(),
        'opening_time': draft.openingTime,
        'closing_time': draft.closingTime,
        'timezone': 'Africa/Dar_es_Salaam',
      });
      cancelShopEdit();
      await load();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> pickReplacementProductImages() async {
    final images = await picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;
    if (images.length != 3) {
      if (mounted) {
        showError(context, Exception('Choose exactly 3 replacement images.'));
      }
      return;
    }
    setState(() => replacementProductImages = images.take(3).toList());
  }

  Future<void> pickReplacementProductVideo() async {
    if (replacementProductVideos.length >= 2) return;
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (video == null || !mounted) return;
    setState(
      () => replacementProductVideos = [...replacementProductVideos, video],
    );
  }

  Future<void> saveProductEdit(Map<String, dynamic> product) async {
    final draft = productDraft;
    if (draft == null) return;
    try {
      if (replacementProductImages.isNotEmpty ||
          replacementProductVideos.isNotEmpty ||
          clearReplacementProductVideos) {
        if (replacementProductImages.isNotEmpty &&
            replacementProductImages.length != 3) {
          throw Exception('Choose exactly 3 product images.');
        }
        await widget.client.postMultipartMedia(
          '/products/${product['id']}',
          fields: {
            'name': draft.name.text.trim(),
            'description': draft.description.text.trim(),
            'price': draft.price.text,
            'discount_percent': draft.discount.text,
            'delivery_price': draft.delivery.text,
            'stock': draft.stock.text,
            if (clearReplacementProductVideos) 'clear_videos': '1',
          },
          images: replacementProductImages
              .map((image) => File(image.path))
              .toList(),
          videos: replacementProductVideos
              .map((video) => File(video.path))
              .toList(),
        );
      } else {
        await widget.client.put('/products/${product['id']}', {
          'name': draft.name.text.trim(),
          'description': draft.description.text.trim(),
          'price': double.parse(draft.price.text),
          'discount_percent': double.tryParse(draft.discount.text) ?? 0,
          'delivery_price': double.parse(draft.delivery.text),
          'stock': int.parse(draft.stock.text),
        });
      }
      cancelProductEdit();
      await load();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> removeProduct(Map<String, dynamic> product) async {
    try {
      await widget.client.delete('/products/${product['id']}');
      if (editingProductId == product['id']) cancelProductEdit();
      await load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product removed.')));
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> inviteDeliverer() async {
    final phone = normalizePhoneInput(delivererPhone.text);
    if (phone.isEmpty) {
      showError(context, Exception('Enter the deliverer phone number.'));
      return;
    }
    try {
      requireTwelveDigitPhone(phone);
    } catch (error) {
      showError(context, error);
      return;
    }

    setState(() => invitingDeliverer = true);
    try {
      final r = await widget.client.post('/seller/deliverer-invitations', {
        'name': delivererName.text.trim(),
        'phone': phone,
      });
      delivererName.clear();
      delivererPhone.clear();
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r['message'] ?? 'Deliverer invited.'}')),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => invitingDeliverer = false);
    }
  }

  @override
  void dispose() {
    shopName.dispose();
    address.dispose();
    shopRegistrationPhone.dispose();
    productName.dispose();
    description.dispose();
    price.dispose();
    discount.dispose();
    delivery.dispose();
    stock.dispose();
    delivererName.dispose();
    delivererPhone.dispose();
    campaignPhone.dispose();
    for (final controller in campaignResendPhones.values) {
      controller.dispose();
    }
    for (final controller in shopResendPhones.values) {
      controller.dispose();
    }
    shopDraft?.dispose();
    productDraft?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSelectedShop = selectedShop();
    final selectedShopCanPublish =
        activeSelectedShop == null || activeSelectedShop['is_active'] == true;

    return ResponsiveSectionListView(
      menuTitle: 'Seller menu',
      menuItems: [
        SectionMenuItem(
          label: 'Open shop',
          icon: Icons.add_business_outlined,
          key: sellerOpenShopKey,
        ),
        SectionMenuItem(
          label: 'Campaigns',
          icon: Icons.campaign_outlined,
          key: sellerCampaignsKey,
        ),
        SectionMenuItem(
          label: 'Deliverer',
          icon: Icons.delivery_dining_outlined,
          key: sellerDelivererKey,
        ),
        SectionMenuItem(
          label: 'List product',
          icon: Icons.add_box_outlined,
          key: sellerListProductKey,
        ),
        SectionMenuItem(
          label: 'Seller products',
          icon: Icons.storefront_outlined,
          key: sellerProductsKey,
        ),
      ],
      maxWidth: kResponsiveContentMaxWidth,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 168,
      ),
      children: [
        SurfacePanel(
          key: sellerOpenShopKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: 'Open shop'),
              const SizedBox(height: 12),
              Field(
                controller: shopName,
                label: 'Shop name',
                icon: Icons.store_outlined,
              ),
              CategoryMultiSelect(
                categories: shopCategories,
                selected: selectedCategories,
                onChanged: (categories) => setState(() {
                  selectedCategories
                    ..clear()
                    ..addAll(categories);
                }),
              ),
              Field(
                controller: address,
                label: 'Address',
                icon: Icons.place_outlined,
              ),
              responsiveScheduleButtons(
                openingKey: const ValueKey('shop-opening-time'),
                closingKey: const ValueKey('shop-closing-time'),
                onOpeningPressed: () => pickShopTime(opening: true),
                onClosingPressed: () => pickShopTime(opening: false),
                openingLabel: 'Opens ${openingTime.format(context)}',
                closingLabel: 'Closes ${closingTime.format(context)}',
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Times use the shop timezone (Africa/Dar_es_Salaam). Overnight hours are supported.',
                  style: TextStyle(color: kTextColor, fontSize: 12),
                ),
              ),
              PaymentInfoBox(
                icon: registrationFeeEnabled()
                    ? Icons.payments_outlined
                    : Icons.check_circle_outline,
                active: registrationFeeEnabled(),
                text: registrationFeeEnabled()
                    ? 'New shops pay TZS ${money.format(registrationFeeAmount())} via ClickPesa USSD before they become active. The prompt is sent to the payment phone below.'
                    : 'Shop registration fee is currently waived by the backend.',
              ),
              const SizedBox(height: 12),
              if (registrationFeeEnabled())
                Field(
                  controller: shopRegistrationPhone,
                  label: 'ClickPesa payment phone',
                  icon: Icons.phone_android_outlined,
                  keyboard: TextInputType.phone,
                ),
              FilledButton.icon(
                key: const ValueKey('save-shop'),
                onPressed: sellerUssdBusy ? null : saveShop,
                icon: creatingShop
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_business),
                label: Text(
                  creatingShop
                      ? registrationFeeEnabled()
                            ? 'Sending registration payment...'
                            : 'Saving shop...'
                      : registrationFeeEnabled()
                      ? 'Save shop and send fee push'
                      : 'Save shop',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SurfacePanel(
          key: sellerCampaignsKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: 'Product campaigns'),
              const SizedBox(height: 6),
              const Text(
                'Promote one of your products to all currently eligible users. DiscountLink creates the message; sellers cannot edit campaign copy.',
                style: TextStyle(color: kTextColor, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (sellerProducts().isEmpty)
                const PaymentInfoBox(
                  icon: Icons.inventory_2_outlined,
                  text: 'Publish an active product before creating a campaign.',
                )
              else ...[
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: campaignProductId,
                  items: [
                    for (final product in sellerProducts())
                      DropdownMenuItem(
                        value: product['id'] as int,
                        child: Text(
                          '${product['name']} · ${product['shop_name'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => campaignProductId = value),
                  decoration: const InputDecoration(labelText: 'Product'),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'fcm',
                      icon: Icon(Icons.notifications_active_outlined),
                      label: Text('FCM'),
                    ),
                    ButtonSegment(
                      value: 'sms',
                      icon: Icon(Icons.sms_outlined),
                      label: Text('SMS'),
                    ),
                  ],
                  selected: {campaignChannel},
                  onSelectionChanged: (selection) =>
                      setState(() => campaignChannel = selection.first),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final pricing = selectedCampaignPricing();
                    final unit =
                        num.tryParse('${pricing['unit_price'] ?? 0}') ?? 0;
                    final count = pricing['eligible_recipient_count'] ?? 0;
                    final total =
                        num.tryParse('${pricing['estimated_total'] ?? 0}') ?? 0;
                    return PaymentInfoBox(
                      icon: Icons.campaign_outlined,
                      active: total > 0,
                      text:
                          '${campaignChannel.toUpperCase()}: TZS ${money.format(unit)} per recipient · $count eligible users · estimated TZS ${money.format(total)}',
                    );
                  },
                ),
                const SizedBox(height: 12),
                if ((num.tryParse(
                          '${selectedCampaignPricing()['estimated_total'] ?? 0}',
                        ) ??
                        0) >
                    0)
                  Field(
                    controller: campaignPhone,
                    label: 'ClickPesa payment phone',
                    icon: Icons.phone_android_outlined,
                    keyboard: TextInputType.phone,
                  ),
                FilledButton.icon(
                  onPressed: sellerUssdBusy || !campaignQuoteIsReady()
                      ? null
                      : createCampaign,
                  icon: creatingCampaign
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: Text(
                    creatingCampaign
                        ? 'Creating campaign...'
                        : loadingCampaigns
                        ? 'Loading campaign price...'
                        : !campaignQuoteIsReady()
                        ? 'Campaign unavailable'
                        : 'Create campaign',
                  ),
                ),
              ],
              if (loadingCampaigns) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ] else if (campaigns.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Recent campaigns',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final rawCampaign in campaigns)
                  Builder(
                    builder: (context) {
                      final campaign = (rawCampaign as Map)
                          .cast<String, dynamic>();
                      final status = '${campaign['status'] ?? 'pending'}';
                      final pendingPayment =
                          status == 'pending_payment' ||
                          status == 'payment_failed';
                      final paymentId = int.tryParse(
                        '${(campaign['payment'] as Map?)?['id'] ?? ''}',
                      );
                      final isResending =
                          paymentId != null &&
                          resendingCampaignPaymentId == paymentId;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: kPrimaryLightColor,
                              child: Icon(
                                campaign['channel'] == 'sms'
                                    ? Icons.sms_outlined
                                    : Icons.notifications_outlined,
                                color: kPrimaryColor,
                              ),
                            ),
                            title: Text(
                              '${campaign['product']?['name'] ?? 'Product campaign'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${campaign['sent_count'] ?? 0}/${campaign['recipient_count'] ?? 0} sent · $status · TZS ${money.format(num.tryParse('${campaign['total_cost'] ?? 0}') ?? 0)}',
                            ),
                            trailing: pendingPayment && paymentId != null
                                ? IconButton(
                                    key: ValueKey(
                                      'campaign-${campaign['id']}-payment-resend',
                                    ),
                                    tooltip: isResending
                                        ? 'Sending payment request'
                                        : 'Change phone and resend',
                                    onPressed: sellerUssdBusy
                                        ? null
                                        : () => showCampaignResendPrompt(
                                            campaign,
                                          ),
                                    icon: isResending
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.refresh_outlined),
                                  )
                                : null,
                          ),
                          if (pendingPayment &&
                              paymentId != null &&
                              editingCampaignPaymentId == paymentId) ...[
                            const SizedBox(height: 4),
                            ClickPesaResendPromptCard(
                              title: 'Resend campaign payment',
                              subtitle:
                                  'Confirm or change the ClickPesa phone before sending the campaign payment prompt.',
                              controller: campaignResendPhoneController(
                                paymentId,
                                '${(campaign['payment'] as Map?)?['phone'] ?? campaignPhone.text}',
                              ),
                              errorText: campaignResendPhoneError,
                              busy: isResending,
                              onCancel: hideCampaignResendPrompt,
                              onSend: () => resendCampaignPayment(campaign),
                              busyLabel: 'Sending campaign payment...',
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                if (campaignPage > 1 || campaignHasMore) ...[
                  const SizedBox(height: 8),
                  _SellerPaginationControls(
                    label: campaignPageLabel(),
                    previousKey: const ValueKey('campaign-page-previous'),
                    nextKey: const ValueKey('campaign-page-next'),
                    onPrevious: campaignPage > 1
                        ? () => loadCampaigns(page: campaignPage - 1)
                        : null,
                    onNext: campaignHasMore
                        ? () => loadCampaigns(page: campaignPage + 1)
                        : null,
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SurfacePanel(
          key: sellerDelivererKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: 'Add deliverer'),
              const SizedBox(height: 12),
              Field(
                controller: delivererName,
                label: 'Deliverer name',
                icon: Icons.badge_outlined,
              ),
              Field(
                controller: delivererPhone,
                label: 'Deliverer phone',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone,
              ),
              FilledButton.icon(
                onPressed: invitingDeliverer ? null : inviteDeliverer,
                icon: const Icon(Icons.delivery_dining_outlined),
                label: Text(
                  invitingDeliverer ? 'Sending invite...' : 'Invite deliverer',
                ),
              ),
              if (delivererInvitations.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Recent invites',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final invite in delivererInvitations.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: kPrimaryLightColor,
                          child: Icon(
                            invite['sent_at'] == null
                                ? Icons.schedule_send_outlined
                                : Icons.mark_chat_read_outlined,
                            color: kPrimaryColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${invite['name'] ?? 'Deliverer'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${invite['phone']}',
                                style: const TextStyle(
                                  color: kTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          invite['sent_at'] == null ? 'Saved' : 'Sent',
                          style: TextStyle(
                            color: invite['sent_at'] == null
                                ? Colors.orange.shade800
                                : Colors.green.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SurfacePanel(
          key: sellerListProductKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: 'List product'),
              const SizedBox(height: 12),
              if (shops.isNotEmpty)
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: selectedShopId,
                  items: [
                    for (final s in shops)
                      DropdownMenuItem(
                        value: s['id'] as int,
                        child: Text(
                          s['is_active'] == true
                              ? s['name']
                              : '${s['name']} - fee pending',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => selectedShopId = v),
                  decoration: const InputDecoration(labelText: 'Shop'),
                ),
              if (activeSelectedShop != null &&
                  activeSelectedShop['is_active'] != true) ...[
                const SizedBox(height: 8),
                PaymentInfoBox(
                  icon: Icons.lock_outline,
                  text:
                      '${shopRegistrationStatus(activeSelectedShop)}. Products can be added after ClickPesa confirms the shop registration fee.',
                  active: true,
                ),
              ],
              const SizedBox(height: 12),
              Field(
                controller: productName,
                label: 'Product name',
                icon: Icons.inventory_2_outlined,
              ),
              Field(
                controller: description,
                label: 'Description',
                icon: Icons.notes,
              ),
              Field(
                controller: price,
                label: 'Price',
                icon: Icons.sell_outlined,
                keyboard: TextInputType.number,
              ),
              Field(
                controller: discount,
                label: 'Discount percent',
                icon: Icons.percent,
                keyboard: TextInputType.number,
              ),
              Field(
                controller: delivery,
                label: 'Delivery price',
                icon: Icons.delivery_dining,
                keyboard: TextInputType.number,
              ),
              Field(
                controller: stock,
                label: 'Stock',
                icon: Icons.numbers,
                keyboard: TextInputType.number,
              ),
              OutlinedButton.icon(
                onPressed: pickProductImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  selectedProductImages.isEmpty
                      ? 'Choose product images'
                      : '${selectedProductImages.length} phone images chosen',
                ),
              ),
              if (selectedProductImages.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(selectedProductImages[index].path),
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemCount: selectedProductImages.length,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: selectedProductVideos.length >= 2
                    ? null
                    : pickProductVideo,
                icon: const Icon(Icons.video_library_outlined),
                label: Text(
                  selectedProductVideos.isEmpty
                      ? 'Add product video (up to 2)'
                      : '${selectedProductVideos.length} of 2 videos chosen',
                ),
              ),
              if (selectedProductVideos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (
                      var index = 0;
                      index < selectedProductVideos.length;
                      index++
                    )
                      InputChip(
                        avatar: const Icon(Icons.videocam_outlined, size: 18),
                        label: Text('Video ${index + 1}'),
                        onDeleted: () => setState(
                          () => selectedProductVideos.removeAt(index),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                key: const ValueKey('publish-product'),
                onPressed:
                    selectedShopId == null ||
                        !selectedShopCanPublish ||
                        publishingProduct
                    ? null
                    : publishProduct,
                icon: publishingProduct
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_box_outlined),
                label: Text(
                  publishingProduct
                      ? 'Publishing product...'
                      : 'Publish product',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(key: sellerProductsKey, title: 'Seller products'),
        if (!loadingShops && shopTotal != null) ...[
          const SizedBox(height: 4),
          Text(
            'Showing ${shops.length} of $shopTotal shops',
            style: const TextStyle(color: kTextColor, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        if (loadingShops) const ListLoadingIndicator(),
        for (final s in shops)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['name'] ?? '',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${((s['categories'] as List?) ?? [s['category']]).where((category) => category != null).join(', ')} - ${s['products']?.length ?? 0} products',
                              style: const TextStyle(color: kTextColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              shopRegistrationStatus(s as Map<String, dynamic>),
                              style: TextStyle(
                                color: s['is_active'] == true
                                    ? Colors.green.shade700
                                    : Colors.orange.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${s['is_open'] == true ? 'Open now' : 'Closed now'} · ${s['opening_time'] ?? '--:--'}–${s['closing_time'] ?? '--:--'}',
                              style: TextStyle(
                                color: s['is_open'] == true
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: ValueKey('shop-${s['id']}-edit'),
                        tooltip: 'Edit shop',
                        onPressed: deletingShopId == null && !sellerUssdBusy
                            ? () => startEditShop(s)
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        key: ValueKey('shop-${s['id']}-delete'),
                        tooltip: deletingShopId == s['id']
                            ? 'Deleting shop'
                            : 'Delete shop',
                        onPressed: deletingShopId == null && !sellerUssdBusy
                            ? () => deleteShop(s)
                            : null,
                        color: Colors.red.shade700,
                        icon: deletingShopId == s['id']
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  if (canRetryShopRegistration(s)) ...[
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final paymentId = shopRegistrationPaymentId(s);
                        final isResending =
                            paymentId != null &&
                            resendingShopPaymentId == paymentId;
                        if (paymentId != null &&
                            editingShopPaymentId == paymentId) {
                          final payment =
                              (s['registration_fee_payment'] ??
                                      s['registrationFeePayment'])
                                  as Map?;
                          return ClickPesaResendPromptCard(
                            title: 'Resend registration payment',
                            subtitle:
                                'Confirm or change the ClickPesa phone before sending the registration payment prompt.',
                            controller: shopResendPhoneController(
                              paymentId,
                              '${payment?['phone'] ?? shopRegistrationPhone.text}',
                            ),
                            errorText: shopResendPhoneError,
                            busy: isResending,
                            onCancel: hideShopRegistrationResendPrompt,
                            onSend: () => resendShopRegistrationPayment(s),
                            busyLabel: 'Sending registration payment...',
                          );
                        }
                        return ClickPesaResendPromptButton(
                          key: ValueKey(
                            'shop-${s['id']}-registration-payment-resend',
                          ),
                          label: 'Change phone and resend registration payment',
                          onPressed: sellerUssdBusy
                              ? null
                              : () => showShopRegistrationResendPrompt(s),
                        );
                      },
                    ),
                  ],
                  if (editingShopId == s['id'] && shopDraft != null) ...[
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Field(
                              controller: shopDraft!.name,
                              label: 'Shop name',
                              icon: Icons.store,
                            ),
                            CategoryMultiSelect(
                              categories: shopCategories,
                              selected: shopDraft!.categories,
                              onChanged: (next) => setState(() {
                                shopDraft!.categories
                                  ..clear()
                                  ..addAll(next);
                              }),
                            ),
                            Field(
                              controller: shopDraft!.address,
                              label: 'Address',
                              icon: Icons.place_outlined,
                            ),
                            responsiveScheduleButtons(
                              openingKey: ValueKey(
                                'shop-${s['id']}-opening-time',
                              ),
                              closingKey: ValueKey(
                                'shop-${s['id']}-closing-time',
                              ),
                              onOpeningPressed: () =>
                                  pickDraftShopTime(opening: true),
                              onClosingPressed: () =>
                                  pickDraftShopTime(opening: false),
                              openingLabel: 'Opens ${shopDraft!.openingTime}',
                              closingLabel: 'Closes ${shopDraft!.closingTime}',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: cancelShopEdit,
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    key: ValueKey('shop-${s['id']}-save-edit'),
                                    onPressed: () => saveShopEdit(s),
                                    child: const Text('Save shop'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  for (final product in visibleProductsForShop(s))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: kSurfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: DecoratedBox(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                        ),
                                        child: ProductImage(
                                          source: productImageSource(
                                            product as Map<String, dynamic>,
                                            fallback:
                                                'assets/images/product_popular_1.png',
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['name'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'TZS ${product['auto_total']} total',
                                          style: const TextStyle(
                                            color: kPrimaryColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '${product['stock'] ?? 0} in stock',
                                          style: const TextStyle(
                                            color: kTextColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        RatingSummary(
                                          product: product,
                                          compact: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit product',
                                    onPressed: () => startEditProduct(product),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove product',
                                    onPressed: () => removeProduct(product),
                                    color: Colors.red.shade700,
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              if (editingProductId == product['id'] &&
                                  productDraft != null) ...[
                                const SizedBox(height: 12),
                                Field(
                                  controller: productDraft!.name,
                                  label: 'Product name',
                                  icon: Icons.inventory_2_outlined,
                                ),
                                Field(
                                  controller: productDraft!.description,
                                  label: 'Description',
                                  icon: Icons.notes,
                                ),
                                Field(
                                  controller: productDraft!.price,
                                  label: 'Price',
                                  icon: Icons.sell_outlined,
                                  keyboard: TextInputType.number,
                                ),
                                Field(
                                  controller: productDraft!.discount,
                                  label: 'Discount percent',
                                  icon: Icons.percent,
                                  keyboard: TextInputType.number,
                                ),
                                Field(
                                  controller: productDraft!.delivery,
                                  label: 'Delivery price',
                                  icon: Icons.delivery_dining,
                                  keyboard: TextInputType.number,
                                ),
                                Field(
                                  controller: productDraft!.stock,
                                  label: 'Stock',
                                  icon: Icons.numbers,
                                  keyboard: TextInputType.number,
                                ),
                                OutlinedButton.icon(
                                  onPressed: pickReplacementProductImages,
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: Text(
                                    replacementProductImages.isEmpty
                                        ? 'Replace images'
                                        : '${replacementProductImages.length} images chosen',
                                  ),
                                ),
                                if (replacementProductImages.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 64,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder: (context, index) =>
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              File(
                                                replacementProductImages[index]
                                                    .path,
                                              ),
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 8),
                                      itemCount:
                                          replacementProductImages.length,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                OutlinedButton.icon(
                                  onPressed:
                                      clearReplacementProductVideos ||
                                          replacementProductVideos.length >= 2
                                      ? null
                                      : pickReplacementProductVideo,
                                  icon: const Icon(
                                    Icons.video_library_outlined,
                                  ),
                                  label: Text(
                                    replacementProductVideos.isEmpty
                                        ? productVideoCount(product) > 0
                                              ? 'Replace all videos (up to 2)'
                                              : 'Add videos (up to 2)'
                                        : '${replacementProductVideos.length} replacement videos',
                                  ),
                                ),
                                if (replacementProductVideos.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      for (
                                        var index = 0;
                                        index < replacementProductVideos.length;
                                        index++
                                      )
                                        InputChip(
                                          avatar: const Icon(
                                            Icons.videocam_outlined,
                                            size: 18,
                                          ),
                                          label: Text('Video ${index + 1}'),
                                          onDeleted: () => setState(
                                            () => replacementProductVideos
                                                .removeAt(index),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (productVideoCount(product) > 0)
                                  CheckboxListTile(
                                    value: clearReplacementProductVideos,
                                    onChanged: (value) => setState(() {
                                      clearReplacementProductVideos =
                                          value ?? false;
                                      if (clearReplacementProductVideos) {
                                        replacementProductVideos = [];
                                      }
                                    }),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Remove all videos'),
                                    subtitle: const Text(
                                      'Saving will remove every current product video.',
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: cancelProductEdit,
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () =>
                                            saveProductEdit(product),
                                        child: const Text('Save product'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (productsForShop(s).length > productPageSize) ...[
                    const SizedBox(height: 2),
                    _SellerPaginationControls(
                      label: productPageLabel(s),
                      previousKey: ValueKey(
                        'shop-${s['id']}-products-previous',
                      ),
                      nextKey: ValueKey('shop-${s['id']}-products-next'),
                      onPrevious: productPageForShop(s) > 1
                          ? () =>
                                changeProductPage(s, productPageForShop(s) - 1)
                          : null,
                      onNext: productPageForShop(s) < productPageCount(s)
                          ? () =>
                                changeProductPage(s, productPageForShop(s) + 1)
                          : null,
                    ),
                  ],
                  if (productsForShop(s).isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        s['is_active'] == true
                            ? 'No products in this shop yet.'
                            : 'Pay the registration fee to activate this shop and start adding products.',
                        style: const TextStyle(color: kTextColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (!loadingShops && shopHasMore) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: loadingMoreShops ? null : () => load(append: true),
            icon: loadingMoreShops
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more),
            label: Text(loadingMoreShops ? 'Loading...' : 'Load more shops'),
          ),
        ],
        const SizedBox(height: 48),
      ],
    );
  }
}
