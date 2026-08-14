part of '../../../../../main.dart';

class _ProductMediaTileState extends State<ProductMediaTile> {
  VideoPlayerController? controller;
  Future<void>? initialization;

  bool get isVideo => widget.media['type'] == 'video';
  String get source => normalizeMediaSource('${widget.media['url'] ?? ''}');

  @override
  void initState() {
    super.initState();
    initializeVideo();
  }

  @override
  void didUpdateWidget(covariant ProductMediaTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media['url'] != widget.media['url'] ||
        oldWidget.media['type'] != widget.media['type']) {
      disposeVideo();
      initializeVideo();
      return;
    }
    if (!oldWidget.active && widget.active) {
      unawaited(playVideo());
    }
    if (oldWidget.active && !widget.active) {
      pauseVideo();
    }
  }

  void initializeVideo() {
    if (!isVideo || source.isEmpty) return;
    final uri = Uri.tryParse(source);
    final nextController =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
        ? VideoPlayerController.networkUrl(uri)
        : VideoPlayerController.file(File(source));
    controller = nextController;
    initialization = nextController.initialize().then((_) async {
      if (!mounted || controller != nextController) return;
      await nextController.setLooping(true);
      if (!mounted || controller != nextController) return;
      if (widget.active) {
        await nextController.play();
      } else {
        await nextController.pause();
      }
      if (mounted && controller == nextController) setState(() {});
    });
  }

  Future<void> playVideo() async {
    final player = controller;
    if (player == null ||
        !player.value.isInitialized ||
        player.value.isPlaying ||
        !widget.active) {
      return;
    }
    await player.play();
    if (mounted && controller == player) setState(() {});
  }

  void pauseVideo() {
    final player = controller;
    if (player == null ||
        !player.value.isInitialized ||
        !player.value.isPlaying) {
      return;
    }
    unawaited(
      player.pause().whenComplete(() {
        if (mounted && controller == player) setState(() {});
      }),
    );
  }

  void disposeVideo() {
    final player = controller;
    controller = null;
    initialization = null;
    if (player != null) unawaited(player.dispose());
  }

  Future<void> toggleVideo() async {
    final player = controller;
    if (player == null || !player.value.isInitialized || !widget.active) {
      return;
    }
    if (player.value.isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
    if (mounted && controller == player && !widget.active) {
      await player.pause();
    }
    if (mounted && controller == player) setState(() {});
  }

  @override
  void dispose() {
    disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isVideo) {
      return ProductImage(source: source, fit: widget.fit);
    }
    final player = controller;
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Icon(Icons.broken_image_outlined));
        }
        if (snapshot.connectionState != ConnectionState.done ||
            player == null ||
            !player.value.isInitialized) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.active ? toggleVideo : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: player.value.aspectRatio == 0
                      ? 1
                      : player.value.aspectRatio,
                  child: VideoPlayer(player),
                ),
              ),
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: player.value.isPlaying ? 0.24 : 1,
                  child: IconButton.filled(
                    tooltip: player.value.isPlaying
                        ? 'Pause video'
                        : 'Play video',
                    onPressed: widget.active ? toggleVideo : null,
                    icon: Icon(
                      player.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
