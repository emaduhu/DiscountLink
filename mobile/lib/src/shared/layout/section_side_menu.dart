part of '../../../main.dart';

class SectionSideMenu extends StatelessWidget {
  const SectionSideMenu({
    super.key,
    required this.title,
    required this.items,
    this.onItemSelected,
    this.useTopSafeArea = false,
  });

  final String title;
  final List<SectionMenuItem> items;
  final ValueChanged<SectionMenuItem>? onItemSelected;
  final bool useTopSafeArea;

  void _handleItemSelected(SectionMenuItem item) {
    final handler = onItemSelected;
    if (handler != null) {
      handler(item);
      return;
    }
    jumpToSection(item.key);
  }

  @override
  Widget build(BuildContext context) {
    final surfaceGradient = appIsDark(context)
        ? const [kDarkSurfaceColor, kDarkScaffoldColor]
        : const [Colors.white, kSurfaceColor];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: surfaceGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(right: BorderSide(color: appBorderColor(context))),
        boxShadow: [
          BoxShadow(
            color: appShadowColor(context, lightAlpha: 0.05, darkAlpha: 0.26),
            blurRadius: 24,
            offset: const Offset(8, 0),
          ),
        ],
      ),
      child: SafeArea(
        top: useTopSafeArea,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimaryColor, kPrimaryColor2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.route_outlined,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tx('Quick navigation', 'Urambazaji wa haraka'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < items.length; index++)
                _buildMenuItem(context, items[index], index),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, SectionMenuItem item, int index) {
    final destructive = item.icon == Icons.delete_outline;
    final accent = destructive ? Colors.red.shade600 : kPrimaryColor;
    return Padding(
      padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 8),
      child: Material(
        color: appSurfaceColor(
          context,
        ).withValues(alpha: appIsDark(context) ? 0.86 : 0.92),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _handleItemSelected(item),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: appBorderColor(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, size: 17, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: destructive ? accent : appForegroundColor(context),
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: appMutedTextColor(context).withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
