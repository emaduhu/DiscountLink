part of '../../../../../main.dart';

class _OrdersPageState extends State<OrdersPage> {
  List orders = [];
  Timer? refreshTimer;
  bool loading = true;
  bool refreshing = false;
  bool loadingMore = false;
  int orderPage = 1;
  int? orderTotal;
  bool orderHasMore = false;
  DateTime? lastUpdated;

  @override
  void initState() {
    super.initState();
    load(showLoading: true);
    refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => load(silent: true),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> load({
    bool showLoading = false,
    bool silent = false,
    bool append = false,
  }) async {
    if (refreshing || loadingMore) return;
    if (showLoading && mounted) {
      setState(() => loading = true);
    } else if (append && mounted) {
      setState(() => loadingMore = true);
    }
    refreshing = !append;
    final page = append ? orderPage + 1 : 1;
    try {
      final r = await widget.client.get('/orders/active', {
        'page': '$page',
        'per_page': '20',
      });
      final orderResponse = r['orders'];
      final nextOrders = responseItems(orderResponse);
      if (mounted) {
        setState(() {
          orders = append ? [...orders, ...nextOrders] : nextOrders;
          orderPage = page;
          orderTotal = responseTotal(orderResponse);
          orderHasMore = responseHasMore(orderResponse);
          lastUpdated = DateTime.now();
          loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => loading = false);
        if (!silent) showError(context, error);
      }
    } finally {
      refreshing = false;
      if (mounted) setState(() => loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => load(),
    child: ResponsiveListView(
      maxWidth: kResponsiveContentMaxWidth,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionTitle(
          title: 'My orders',
          action: refreshing ? 'Updating' : 'Refresh',
          onAction: refreshing ? null : () => load(showLoading: orders.isEmpty),
        ),
        if (lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Updated ${DateFormat('HH:mm').format(lastUpdated!)}',
              style: const TextStyle(color: kTextColor, fontSize: 12),
            ),
          ),
        if (!loading && orderTotal != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Showing ${orders.length} of $orderTotal orders',
              style: const TextStyle(color: kTextColor, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        if (loading)
          const ListLoadingIndicator()
        else if (orders.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No active orders',
            subtitle: 'Orders waiting for delivery tracking will appear here.',
          ),
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TrackingCard(order: order as Map<String, dynamic>),
          ),
        if (!loading && orderHasMore)
          OutlinedButton.icon(
            onPressed: loadingMore ? null : () => load(append: true),
            icon: loadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more),
            label: Text(loadingMore ? 'Loading...' : 'Load more orders'),
          ),
      ],
    ),
  );
}
