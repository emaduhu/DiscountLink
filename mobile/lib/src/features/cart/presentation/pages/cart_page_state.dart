part of '../../../../../main.dart';

class _CartPageState extends State<CartPage> {
  final addressLine = TextEditingController();
  final city = TextEditingController(text: 'Dar es Salaam');
  final landmark = TextEditingController();
  final checkoutPhone = TextEditingController();
  final resendPaymentPhone = TextEditingController();
  final cartItemsKey = GlobalKey();
  final cartPaymentKey = GlobalKey();
  final cartDeliveryKey = GlobalKey();
  final money = NumberFormat('#,##0.00');
  List cart = [];
  Map<String, dynamic> serviceFee = {
    'rate': 0,
    'amount': 0,
    'currency': 'TZS',
    'enabled': false,
  };
  bool loading = true;
  bool checkingOut = false;
  bool resendingPaymentPrompt = false;
  bool showingResendPaymentPrompt = false;
  String? checkoutPaymentStatus;
  String? resendPaymentPhoneError;
  Map<String, dynamic>? lastCheckoutPayment;
  Map<String, dynamic>? lastCheckoutPush;
  Map<String, dynamic>? lastCheckoutOrder;
  String? lastDeliveryCode;

  @override
  void initState() {
    super.initState();
    addressLine.text = widget.user['address'] ?? '';
    checkoutPhone.text = widget.user['phone'] ?? '';
    load();
  }

  @override
  void dispose() {
    addressLine.dispose();
    city.dispose();
    landmark.dispose();
    checkoutPhone.dispose();
    resendPaymentPhone.dispose();
    super.dispose();
  }

  String checkoutAddress() => [
    addressLine.text.trim(),
    city.text.trim(),
    landmark.text.trim(),
  ].where((part) => part.isNotEmpty).join(', ');

  double cartUnitPrice(Map<String, dynamic> item) {
    final override = num.tryParse('${item['unit_price_override'] ?? ''}');
    if (override != null) return override.toDouble();
    final product = (item['product'] as Map).cast<String, dynamic>();

    return productBuyerPrice(product);
  }

  double cartDeliveryPrice(Map<String, dynamic> item) {
    final product = (item['product'] as Map).cast<String, dynamic>();
    return productDeliveryPrice(product);
  }

  double cartSubtotal() => cart.fold<double>(0, (total, item) {
    final row = item as Map<String, dynamic>;
    final quantity = (num.tryParse('${row['quantity'] ?? 1}') ?? 1).toDouble();
    return total + (cartUnitPrice(row) * quantity);
  });

  double cartDeliveryTotal() => cart.fold<double>(0, (total, item) {
    final row = item as Map<String, dynamic>;
    final quantity = (num.tryParse('${row['quantity'] ?? 1}') ?? 1).toDouble();
    return total + (cartDeliveryPrice(row) * quantity);
  });

  double serviceFeeRate() => double.tryParse('${serviceFee['rate'] ?? 0}') ?? 0;

  double serviceFeeAmount() =>
      double.tryParse('${serviceFee['amount'] ?? 0}') ??
      (cartSubtotal() * (serviceFeeRate() / 100));

  double cartGrandTotal() =>
      cartSubtotal() + cartDeliveryTotal() + serviceFeeAmount();

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final r = await widget.client.get('/cart');
      if (!mounted) return;
      setState(() {
        cart = r['items'] as List;
        serviceFee =
            (r['service_fee'] as Map?)?.cast<String, dynamic>() ??
            {'rate': 0, 'amount': 0, 'currency': 'TZS', 'enabled': false};
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> removeCartItem(Map<String, dynamic> item) async {
    await widget.client.delete('/cart/${item['product']['id']}');
    await load();
  }

  Future<void> saveAddress() async {
    final r = await widget.client.put('/me', {'address': checkoutAddress()});
    widget.onUserChanged(r['user'] as Map<String, dynamic>);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx('Address saved.', 'Anwani imehifadhiwa.'))),
    );
  }

  Future<void> checkout() async {
    if (checkingOut || resendingPaymentPrompt) return;
    var resendAfterCheckout = false;
    setState(() {
      checkingOut = true;
      checkoutPaymentStatus = tx(
        'Creating your order and preparing ClickPesa...',
        'Inatengeneza oda na kuandaa ClickPesa...',
      );
    });
    try {
      final paymentPhone = requireTwelveDigitPhone(checkoutPhone.text);
      setState(() {
        checkoutPaymentStatus = tx(
          'Sending a USSD payment push to $paymentPhone...',
          'Inatuma ombi la malipo ya USSD kwenda $paymentPhone...',
        );
      });
      final r = await widget.client.post('/checkout', {
        'delivery_address': checkoutAddress(),
        'phone': paymentPhone,
      });
      if (!mounted) return;
      setState(() {
        checkoutPaymentStatus = tx(
          'USSD push sent. Approve it on your phone to complete payment.',
          'Ombi la USSD limetumwa. Likubali kwenye simu yako kukamilisha malipo.',
        );
      });
      final push = r['ussd_push'] as Map<String, dynamic>?;
      final payment = r['payment'] as Map<String, dynamic>?;
      final deliveryCode = '${r['delivery_code'] ?? ''}'.trim();
      setState(() {
        lastCheckoutPayment = payment;
        lastCheckoutPush = push;
        lastCheckoutOrder = (r['order'] as Map?)?.cast<String, dynamic>();
        lastDeliveryCode = deliveryCode.isEmpty ? null : deliveryCode;
        resendPaymentPhone.text = '${payment?['phone'] ?? paymentPhone}';
      });
      final deliveryNotifications =
          (r['delivery_code_notifications'] as Map?)?.cast<String, dynamic>() ??
          {};
      final deliveryNotificationSummary = [
        if (deliveryNotifications['sms'] == true) 'SMS',
        if (deliveryNotifications['fcm'] == true) 'push notification',
      ];
      final deliveryCodeMessage = deliveryCode.isEmpty
          ? tx(
              'Your buyer delivery code will appear in My orders when it is ready.',
              'Kodi yako ya kupokea mzigo itaonekana kwenye Oda zangu ikiwa tayari.',
            )
          : '${tx('Approve the USSD prompt on your phone. Keep this buyer delivery code:', 'Kubali ombi la USSD kwenye simu yako. Hifadhi kodi hii ya kupokea mzigo:')} $deliveryCode';
      final deliveryNotificationMessage = deliveryCode.isEmpty
          ? tx(
              'Keep checking My orders before sharing any delivery confirmation.',
              'Endelea kuangalia Oda zangu kabla ya kutoa uthibitisho wowote wa mzigo.',
            )
          : deliveryNotificationSummary.isEmpty
          ? tx(
              'We could not confirm an SMS or push copy; keep the code shown here.',
              'Hatujaweza kuthibitisha nakala ya SMS au arifa; hifadhi kodi iliyo hapa.',
            )
          : tx(
              'A copy was also sent by ${deliveryNotificationSummary.join(' and ')}.',
              'Nakala pia imetumwa kwa ${deliveryNotificationSummary.join(' na ')}.',
            );
      resendAfterCheckout =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(
                tx('Payment request sent', 'Ombi la malipo limetumwa'),
              ),
              content: SingleChildScrollView(
                child: Text(
                  '${tx('Order', 'Oda')}: ${r['order']['reference']}\n'
                  '${tx('Amount', 'Kiasi')}: TZS ${money.format(num.tryParse('${r['order']['grand_total'] ?? cartGrandTotal()}') ?? cartGrandTotal())}\n'
                  '${paymentRequestDetails(payment: payment, push: push, fallbackPhone: paymentPhone)}\n\n'
                  '$deliveryCodeMessage\n\n'
                  '$deliveryNotificationMessage\n\n'
                  '${tx('Share the delivery code only after the order arrives.', 'Toa kodi ya mzigo baada tu ya kupokea oda yako.')}',
                ),
              ),
              actionsOverflowButtonSpacing: 8,
              actions: [
                if (payment?['id'] != null)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(
                      tx('Resend Payment request', 'Tuma tena ombi la malipo'),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('OK'),
                ),
              ],
            ),
          ) ??
          false;
      await load();
    } catch (error) {
      if (mounted) await showPaymentError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          checkingOut = false;
          checkoutPaymentStatus = null;
        });
      }
    }
    if (resendAfterCheckout && mounted) {
      showResendPaymentPrompt();
    }
  }

  void showResendPaymentPrompt() {
    final phone = '${lastCheckoutPayment?['phone'] ?? checkoutPhone.text}';
    setState(() {
      resendPaymentPhone.text = phone;
      resendPaymentPhoneError = null;
      showingResendPaymentPrompt = true;
    });
  }

  void hideResendPaymentPrompt() {
    if (resendingPaymentPrompt) return;
    setState(() {
      showingResendPaymentPrompt = false;
      resendPaymentPhoneError = null;
    });
  }

  Future<void> resendPaymentPrompt() async {
    if (checkingOut || resendingPaymentPrompt) return;
    final paymentId = lastCheckoutPayment?['id'];
    if (paymentId == null) return;
    late final String paymentPhone;
    try {
      paymentPhone = requireTwelveDigitPhone(resendPaymentPhone.text);
    } catch (error) {
      setState(() {
        resendPaymentPhoneError = error.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
      return;
    }
    checkoutPhone.text = paymentPhone;
    setState(() {
      resendingPaymentPrompt = true;
      resendPaymentPhoneError = null;
      checkoutPaymentStatus = tx(
        'Sending the ClickPesa prompt to $paymentPhone...',
        'Inatuma ombi la ClickPesa kwenda $paymentPhone...',
      );
    });
    try {
      final r = await widget.client.post('/payments/$paymentId/ussd-push', {
        'payment_phone': paymentPhone,
      });
      if (!mounted) return;
      final payment =
          (r['payment'] as Map?)?.cast<String, dynamic>() ??
          lastCheckoutPayment;
      final push =
          (r['ussd_push'] as Map?)?.cast<String, dynamic>() ?? lastCheckoutPush;
      final message =
          '${r['message'] ?? tx('Payment request sent. Check your phone and approve the USSD prompt.', 'Ombi la malipo limetumwa. Angalia simu yako na ukubali ombi la USSD.')}';
      setState(() {
        lastCheckoutPayment = payment;
        lastCheckoutPush = push;
        checkoutPaymentStatus = message;
        showingResendPaymentPrompt = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on TimeoutException {
      if (mounted) {
        await showPaymentError(
          context,
          Exception(
            tx(
              'The payment provider took too long to respond. Check your phone for a USSD request, then tap Resend Payment request if nothing appears.',
              'Mtoa huduma ya malipo amechelewa kujibu. Angalia simu yako kwa ombi la USSD, kisha bonyeza Tuma tena ombi la malipo kama hakuna kinachoonekana.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) await showPaymentError(context, error);
    } finally {
      if (mounted) setState(() => resendingPaymentPrompt = false);
    }
  }

  String paymentRequestDetails({
    required Map<String, dynamic>? payment,
    required Map<String, dynamic>? push,
    required String fallbackPhone,
  }) {
    final initiate = (push?['initiate'] as Map?)?.cast<String, dynamic>();
    final phone = '${payment?['phone'] ?? fallbackPhone}';
    final status = '${payment?['status'] ?? push?['status'] ?? 'processing'}';
    final reference =
        '${push?['reference'] ?? payment?['provider_reference'] ?? push?['orderReference'] ?? '-'}';
    final channel = '${initiate?['channel'] ?? push?['channel'] ?? ''}'.trim();

    return [
      '${tx('Phone', 'Simu')}: $phone',
      '${tx('Payment status', 'Hali ya malipo')}: $status',
      '${tx('Reference', 'Kumbukumbu')}: $reference',
      if (channel.isNotEmpty) '${tx('Channel', 'Mtandao')}: $channel',
    ].join('\n');
  }

  Future<void> showPaymentError(BuildContext context, Object error) async {
    final message = error.toString().replaceFirst('Exception: ', '');
    final mPesaInactive = message.toLowerCase().contains(
      'm-pesa payment method is not active',
    );
    final providerNote = mPesaInactive
        ? '${tx('M-Pesa collections must be activated on the ClickPesa account before Vodacom numbers can receive the request.', 'Malipo ya M-Pesa lazima yawashwe kwenye akaunti ya ClickPesa kabla namba za Vodacom hazijapokea ombi.')}\n\n'
        : '';
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          tx('Payment request was not sent', 'Ombi la malipo halikutumwa'),
        ),
        content: SingleChildScrollView(
          child: Text(
            '$message\n\n'
            '$providerNote'
            '${tx('Your cart is still saved. Check that the payment phone has exactly 12 digits, then try Resend Payment request after the provider issue is resolved.', 'Kikapu chako bado kimehifadhiwa. Hakiki namba ya malipo iwe na tarakimu 12, kisha jaribu Tuma tena ombi la malipo baada ya tatizo la mtoa huduma kutatuliwa.')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('OK', 'Sawa')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx('Cart', 'Kikapu'))),
      body: RefreshIndicator(
        onRefresh: load,
        child: ResponsiveSectionListView(
          menuTitle: tx('Cart menu', 'Menyu ya kikapu'),
          menuItems: [
            SectionMenuItem(
              label: tx('Cart items', 'Bidhaa'),
              icon: Icons.shopping_cart_outlined,
              key: cartItemsKey,
            ),
            SectionMenuItem(
              label: tx('Payment', 'Malipo'),
              icon: Icons.payments_outlined,
              key: cartPaymentKey,
            ),
            SectionMenuItem(
              label: tx('Delivery', 'Usafiri'),
              icon: Icons.local_shipping_outlined,
              key: cartDeliveryKey,
            ),
          ],
          maxWidth: kResponsiveContentMaxWidth,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SurfacePanel(
              key: cartItemsKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    title: '${tx('Cart', 'Kikapu')} (${cart.length})',
                  ),
                  const SizedBox(height: 8),
                  if (loading)
                    const ListLoadingIndicator()
                  else if (cart.isEmpty)
                    Text(
                      tx(
                        'Add products to start checkout.',
                        'Ongeza bidhaa ili kuanza malipo.',
                      ),
                      style: const TextStyle(color: kTextColor),
                    )
                  else
                    for (final i in cart)
                      Builder(
                        builder: (context) {
                          final item = i as Map<String, dynamic>;
                          final override = item['unit_price_override'];
                          final product = item['product'] as Map;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: kPrimaryLightColor,
                              child: Icon(Icons.shopping_bag_outlined),
                            ),
                            title: Text(product['name']),
                            subtitle: Text(
                              override == null
                                  ? 'Qty ${item['quantity']}'
                                  : 'Qty ${item['quantity']} - negotiated TZS $override',
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove item',
                              onPressed: () => removeCartItem(item),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfacePanel(
              key: cartPaymentKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    title: tx('Payment summary', 'Muhtasari wa malipo'),
                  ),
                  const SizedBox(height: 8),
                  PaymentSummaryRow(
                    label: tx('Products', 'Bidhaa'),
                    value: 'TZS ${money.format(cartSubtotal())}',
                  ),
                  PaymentSummaryRow(
                    label: tx('Delivery', 'Usafiri'),
                    value: 'TZS ${money.format(cartDeliveryTotal())}',
                  ),
                  PaymentSummaryRow(
                    label:
                        '${tx('Service fee', 'Ada ya huduma')} (${money.format(serviceFeeRate())}%)',
                    value: 'TZS ${money.format(serviceFeeAmount())}',
                  ),
                  const Divider(height: 20),
                  PaymentSummaryRow(
                    label: tx('Total to pay', 'Jumla ya kulipa'),
                    value: 'TZS ${money.format(cartGrandTotal())}',
                    strong: true,
                  ),
                  const SizedBox(height: 10),
                  PaymentInfoBox(
                    icon: Icons.phone_android_outlined,
                    text: tx(
                      'ClickPesa sends a USSD prompt to the payment phone below. Approve the prompt on that phone to complete payment.',
                      'ClickPesa hutuma ombi la USSD kwenye simu ya malipo hapo chini. Kubali ombi hilo kwenye simu hiyo kukamilisha malipo.',
                    ),
                  ),
                  if (checkoutPaymentStatus != null) ...[
                    const SizedBox(height: 10),
                    PaymentInfoBox(
                      icon: Icons.sync_outlined,
                      text: checkoutPaymentStatus!,
                      active: true,
                    ),
                  ],
                  if (lastCheckoutPayment?['id'] != null) ...[
                    const SizedBox(height: 10),
                    if (showingResendPaymentPrompt)
                      ClickPesaResendPromptCard(
                        title: tx(
                          'Resend ClickPesa prompt',
                          'Tuma tena ombi la ClickPesa',
                        ),
                        subtitle: tx(
                          'Use a different phone if the first one was wrong or has no money.',
                          'Tumia simu nyingine kama ya kwanza ilikuwa si sahihi au haina pesa.',
                        ),
                        controller: resendPaymentPhone,
                        errorText: resendPaymentPhoneError,
                        busy: resendingPaymentPrompt,
                        onCancel: hideResendPaymentPrompt,
                        onSend: resendPaymentPrompt,
                        busyLabel: tx(
                          'Sending payment request...',
                          'Inatuma ombi la malipo...',
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: checkingOut || resendingPaymentPrompt
                              ? null
                              : showResendPaymentPrompt,
                          icon: const Icon(Icons.refresh_outlined),
                          label: Text(
                            tx(
                              'Change phone and resend ClickPesa prompt',
                              'Badili simu na tuma tena ombi la ClickPesa',
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    if (lastCheckoutOrder != null || lastDeliveryCode != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${tx('Last order', 'Oda ya mwisho')}: ${lastCheckoutOrder?['reference'] ?? '-'}'
                          '${lastDeliveryCode == null ? '' : '\n${tx('Delivery code', 'Kodi ya mzigo')}: $lastDeliveryCode'}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: kTextColor),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  SectionTitle(
                    key: cartDeliveryKey,
                    title: tx('Delivery details', 'Taarifa za usafiri'),
                  ),
                  const SizedBox(height: 8),
                  Field(
                    controller: addressLine,
                    label: tx('Street or area', 'Mtaa au eneo'),
                    icon: Icons.place_outlined,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Field(
                          controller: city,
                          label: tx('City', 'Jiji'),
                          icon: Icons.location_city_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Field(
                          controller: landmark,
                          label: tx('Landmark', 'Alama ya eneo'),
                          icon: Icons.flag_outlined,
                        ),
                      ),
                    ],
                  ),
                  Field(
                    controller: checkoutPhone,
                    label: tx('Payment phone', 'Simu ya malipo'),
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                  ),
                  OutlinedButton.icon(
                    onPressed: saveAddress,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(tx('Save address', 'Hifadhi anwani')),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed:
                        cart.isEmpty ||
                            loading ||
                            checkingOut ||
                            resendingPaymentPrompt
                        ? null
                        : checkout,
                    icon: checkingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.payments_outlined),
                    label: Text(
                      checkingOut
                          ? tx('Requesting payment...', 'Inaomba malipo...')
                          : tx(
                              'Pay with ClickPesa USSD',
                              'Lipa kwa ClickPesa USSD',
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
