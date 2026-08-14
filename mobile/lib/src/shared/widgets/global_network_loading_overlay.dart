part of '../../../main.dart';

class GlobalNetworkLoadingOverlay extends StatelessWidget {
  const GlobalNetworkLoadingOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: networkActivity.activeRequests,
      builder: (context, activeRequests, _) {
        final isLoading = activeRequests > 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (isLoading)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Semantics(
                    label: tx('Processing request', 'Inashughulikia ombi'),
                    liveRegion: true,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.20),
                          child: Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.94, end: 1),
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutBack,
                              builder: (context, scale, content) =>
                                  Transform.scale(scale: scale, child: content),
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 260,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.98),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 28,
                                        offset: const Offset(0, 14),
                                      ),
                                      BoxShadow(
                                        color: kPrimaryColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 68,
                                        height: 68,
                                        padding: const EdgeInsets.all(7),
                                        decoration: const BoxDecoration(
                                          color: kPrimaryLightColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            const SizedBox(
                                              width: 54,
                                              height: 54,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 4,
                                                strokeCap: StrokeCap.round,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(kPrimaryColor),
                                              ),
                                            ),
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    kPrimaryColor,
                                                    kPrimaryColor2,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.bolt_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        tx(
                                          'Please wait...',
                                          'Tafadhali subiri...',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: Colors.black,
                                            ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        tx(
                                          'Processing your request',
                                          'Inashughulikia ombi lako',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: kTextColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
