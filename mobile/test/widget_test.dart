import 'dart:async';

import 'package:discount_link/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  testWidgets('renders Discount Link login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          client: ApiClient('https://example.test'),
          onSignedIn: (_, _) {},
        ),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('product carousel activates only the visible media tile', (
    tester,
  ) async {
    const firstImage = 'assets/images/product_popular_1.png';
    const secondImage = 'assets/images/product_headset.png';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: ProductMediaCarousel(
                media: [
                  {'type': 'image', 'url': firstImage},
                  {'type': 'image', 'url': secondImage},
                ],
              ),
            ),
          ),
        ),
      ),
    );

    var activeTiles = tester
        .widgetList<ProductMediaTile>(find.byType(ProductMediaTile))
        .where((tile) => tile.active)
        .toList();
    expect(activeTiles, hasLength(1));
    expect(activeTiles.single.media['url'], firstImage);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    activeTiles = tester
        .widgetList<ProductMediaTile>(find.byType(ProductMediaTile))
        .where((tile) => tile.active)
        .toList();
    expect(activeTiles, hasLength(1));
    expect(activeTiles.single.media['url'], secondImage);
  });

  test('product media sources normalize localhost urls to the API origin', () {
    final sources = productMediaSources({
      'media': [
        {
          'type': 'video',
          'url': 'http://localhost/storage/products/7/videos/demo.mp4',
          'position': 0,
        },
      ],
    }, fallback: 'assets/images/product_popular_1.png');

    expect(
      sources.single['url'],
      'https://dl.vigourtech.net/storage/products/7/videos/demo.mp4',
    );
  });

  test('product image sources normalize cleartext same-host urls', () {
    final sources = productImageSources({
      'images': ['http://dl.vigourtech.net/storage/products/7/images/demo.jpg'],
    }, fallback: 'assets/images/product_popular_1.png');

    expect(
      sources.single,
      'https://dl.vigourtech.net/storage/products/7/images/demo.jpg',
    );
  });

  testWidgets('product carousel plays visible videos and pauses hidden ones', (
    tester,
  ) async {
    final previousPlatform = VideoPlayerPlatform.instance;
    final videoPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
    addTearDown(() {
      VideoPlayerPlatform.instance = previousPlatform;
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: ProductMediaCarousel(
                media: [
                  {
                    'type': 'image',
                    'url': 'assets/images/product_popular_1.png',
                  },
                  {'type': 'video', 'url': 'https://example.test/product.mp4'},
                  {'type': 'image', 'url': 'assets/images/product_headset.png'},
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(videoPlatform.calls, isNot(contains('play')));

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(videoPlatform.calls, contains('createWithOptions'));
    expect(videoPlatform.calls, contains('play'));

    final playIndex = videoPlatform.calls.lastIndexOf('play');
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    final pauseIndex = videoPlatform.calls.lastIndexOf('pause');
    expect(pauseIndex, greaterThan(playIndex));
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<String> calls = <String>[];
  final Map<int, StreamController<VideoEvent>> streams =
      <int, StreamController<VideoEvent>>{};
  int nextPlayerId = 1;

  @override
  Future<void> init() async {
    calls.add('init');
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    return createWithOptions(
      VideoCreationOptions(
        dataSource: dataSource,
        viewType: VideoViewType.textureView,
      ),
    );
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    calls.add('createWithOptions');
    final playerId = nextPlayerId++;
    final stream = StreamController<VideoEvent>();
    streams[playerId] = stream;
    scheduleMicrotask(() {
      if (!stream.isClosed) {
        stream.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 1),
            size: const Size(100, 100),
          ),
        );
      }
    });

    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return streams[playerId]!.stream;
  }

  @override
  Widget buildView(int playerId) {
    return SizedBox(key: ValueKey('fake-video-$playerId'));
  }

  @override
  Future<void> play(int playerId) async {
    calls.add('play');
  }

  @override
  Future<void> pause(int playerId) async {
    calls.add('pause');
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    calls.add('setLooping');
  }

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    await streams.remove(playerId)?.close();
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return Duration.zero;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
