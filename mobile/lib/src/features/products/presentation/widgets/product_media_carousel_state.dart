part of '../../../../../main.dart';

class _ProductMediaCarouselState extends State<ProductMediaCarousel> {
  int current = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.15,
          child: PageView.builder(
            itemCount: widget.media.length,
            onPageChanged: (index) => setState(() => current = index),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: appSubtleSurfaceColor(context),
                  ),
                  child: ProductMediaTile(
                    media: widget.media[index],
                    active: index == current,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.media.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < widget.media.length; index++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: current == index ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: current == index
                        ? kPrimaryColor
                        : appMutedTextColor(context).withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
