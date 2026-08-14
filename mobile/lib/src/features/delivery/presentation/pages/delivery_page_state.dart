part of '../../../../../main.dart';

class _DeliveryPageState extends State<DeliveryPage> {
  List jobs = [];
  final code = TextEditingController();
  Timer? locationTimer;
  bool sharingLocation = false;
  bool loading = true;
  bool refreshing = false;
  bool loadingMoreJobs = false;
  bool updatingAvailability = false;
  bool isAvailable = true;
  int jobPage = 1;
  int? jobTotal;
  bool jobHasMore = false;
  int? acceptingJobId;
  int? completingJobId;
  DateTime? lastRefreshedAt;

  @override
  void initState() {
    super.initState();
    isAvailable = widget.user['is_available'] != false;
    load(showLoading: true);
    locationTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => shareAcceptedLocation(silent: true),
    );
  }

  @override
  void dispose() {
    locationTimer?.cancel();
    code.dispose();
    super.dispose();
  }

  Future<void> load({
    bool showLoading = false,
    bool silent = false,
    bool append = false,
  }) async {
    if (showLoading && mounted) {
      setState(() => loading = true);
    } else if (append && mounted) {
      setState(() => loadingMoreJobs = true);
    } else if (!silent && mounted) {
      setState(() => refreshing = true);
    }
    final page = append ? jobPage + 1 : 1;
    try {
      final r = await widget.client.get('/deliveries', {
        'page': '$page',
        'per_page': '20',
      });
      final jobResponse = r['jobs'];
      final nextJobs = responseItems(jobResponse);
      if (mounted) {
        setState(() {
          jobs = append ? [...jobs, ...nextJobs] : nextJobs;
          jobPage = page;
          jobTotal = responseTotal(jobResponse);
          jobHasMore = responseHasMore(jobResponse);
          isAvailable = r['is_available'] != false;
          lastRefreshedAt = DateTime.now();
        });
      }
    } catch (error) {
      if (mounted && !silent) showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          refreshing = false;
          loadingMoreJobs = false;
        });
      }
    }
  }

  Future<void> setAvailability(bool value) async {
    setState(() {
      updatingAvailability = true;
      isAvailable = value;
    });
    try {
      final r = await widget.client.post('/deliverer/availability', {
        'is_available': value,
      });
      if (r['user'] is Map<String, dynamic>) {
        widget.onUserChanged(r['user'] as Map<String, dynamic>);
      }
      if (!mounted) return;
      setState(() => isAvailable = r['is_available'] != false);
      await load(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r['message'] ?? 'Availability updated.'}')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => isAvailable = !value);
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => updatingAvailability = false);
    }
  }

  Future<void> acceptDelivery(Map<String, dynamic> job) async {
    final id = job['id'] as int?;
    if (id == null) return;
    setState(() => acceptingJobId = id);
    try {
      await widget.client.post('/deliveries/$id/accept', {});
      await load();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => acceptingJobId = null);
    }
  }

  Future<void> completeDelivery(Map<String, dynamic> job) async {
    final id = job['id'] as int?;
    if (id == null) return;
    final deliveryCode = code.text.trim();
    if (deliveryCode.length != 4 ||
        deliveryCode.split('').toSet().length != 4) {
      showError(context, 'Enter exactly 4 different digits from the buyer.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete delivery?'),
        content: Text(
          'Confirm buyer code $deliveryCode for order ${job['order']?['reference'] ?? ''}. This will mark the delivery complete and trigger seller and delivery payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete delivery'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => completingJobId = id);
    try {
      final r = await widget.client.post('/deliveries/$id/complete', {
        'delivery_code': deliveryCode,
      });
      code.clear();
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r['message'] ?? 'Delivery completed.'}')),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => completingJobId = null);
    }
  }

  Future<Position> currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Turn on location services to share tracking.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to track deliveries.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> shareAcceptedLocation({bool silent = false}) async {
    final accepted = jobs
        .where((j) => (j as Map<String, dynamic>)['status'] == 'accepted')
        .cast<Map<String, dynamic>>()
        .toList();
    if (accepted.isEmpty || sharingLocation) return;

    setState(() => sharingLocation = true);
    try {
      final position = await currentPosition();
      for (final job in accepted) {
        await widget.client.post('/deliveries/${job['id']}/location', {
          'latitude': position.latitude,
          'longitude': position.longitude,
        }, showBlockingLoader: false);
      }
      await load(silent: true);
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery location shared.')),
        );
      }
    } catch (error) {
      if (!silent && mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => sharingLocation = false);
    }
  }

  Future<void> callBuyer(String phone) async {
    final normalized = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (normalized.isEmpty) return;
    final dial = normalized.startsWith('+') ? normalized : '+$normalized';
    final uri = Uri(scheme: 'tel', path: dial);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open phone dialer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => load(silent: false),
      child: ResponsiveListView(
        maxWidth: kResponsiveContentMaxWidth,
        padding: const EdgeInsets.all(16),
        children: [
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isAvailable,
                  onChanged: updatingAvailability ? null : setAvailability,
                  title: const Text('Available for deliveries'),
                  subtitle: Text(
                    isAvailable
                        ? 'New nearby delivery requests can be assigned to you.'
                        : 'You will not receive new delivery requests.',
                  ),
                ),
                if (updatingAvailability || refreshing || sharingLocation)
                  const LinearProgressIndicator(minHeight: 3),
                if (lastRefreshedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Updated ${DateFormat('HH:mm:ss').format(lastRefreshedAt!)}',
                    style: const TextStyle(color: kTextColor, fontSize: 12),
                  ),
                ],
                if (!loading && jobTotal != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Showing ${jobs.length} of $jobTotal jobs',
                    style: const TextStyle(color: kTextColor, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const ListLoadingIndicator()
          else if (jobs.isEmpty)
            const EmptyState(
              icon: Icons.delivery_dining_outlined,
              title: 'No delivery jobs',
              subtitle: 'Available delivery requests will appear here.',
            ),
          for (final j in jobs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        j['order']['reference'],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${j['order']['delivery_address']}\nTZS ${j['order']['delivery_total']}',
                      ),
                      if (j['status'] == 'broadcast')
                        FilledButton.icon(
                          onPressed: acceptingJobId == j['id']
                              ? null
                              : () => acceptDelivery(j),
                          icon: acceptingJobId == j['id']
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            acceptingJobId == j['id']
                                ? 'Accepting...'
                                : 'Accept delivery',
                          ),
                        ),
                      if (j['status'] == 'accepted') ...[
                        const SizedBox(height: 8),
                        TrackingMiniMap(
                          shopLatitude: toDouble(
                            j['order']?['shop']?['latitude'],
                          ),
                          shopLongitude: toDouble(
                            j['order']?['shop']?['longitude'],
                          ),
                          delivererLatitude: toDouble(j['deliverer_latitude']),
                          delivererLongitude: toDouble(
                            j['deliverer_longitude'],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if ('${j['order']?['buyer']?['call_phone'] ?? ''}'
                            .trim()
                            .isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${j['order']?['buyer']?['call_phone']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton.filled(
                                tooltip: 'Call buyer',
                                onPressed: () async {
                                  try {
                                    await callBuyer(
                                      '${j['order']?['buyer']?['call_phone']}',
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    showError(context, error);
                                  }
                                },
                                icon: const Icon(Icons.call),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: sharingLocation
                              ? null
                              : () => shareAcceptedLocation(),
                          icon: const Icon(Icons.my_location),
                          label: Text(
                            sharingLocation
                                ? 'Sharing location...'
                                : 'Share current location',
                          ),
                        ),
                        Field(
                          controller: code,
                          label: 'Buyer delivery code (4 unique digits)',
                          icon: Icons.pin,
                          keyboard: TextInputType.number,
                          maxLength: 4,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: completingJobId == j['id']
                              ? null
                              : () => completeDelivery(j),
                          icon: completingJobId == j['id']
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.payments),
                          label: Text(
                            completingJobId == j['id']
                                ? 'Completing delivery...'
                                : 'Confirm code and release payments',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (!loading && jobHasMore)
            OutlinedButton.icon(
              onPressed: loadingMoreJobs ? null : () => load(append: true),
              icon: loadingMoreJobs
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(loadingMoreJobs ? 'Loading...' : 'Load more jobs'),
            ),
        ],
      ),
    );
  }
}
