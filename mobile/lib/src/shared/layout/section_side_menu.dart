part of '../../../main.dart';

class SectionSideMenu extends StatelessWidget {
  const SectionSideMenu({
    super.key,
    required this.title,
    required this.items,
    this.onItemSelected,
  });

  final String title;
  final List<SectionMenuItem> items;
  final ValueChanged<SectionMenuItem>? onItemSelected;

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(6, 0),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: kTextColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextButton.icon(
                    onPressed: () => _handleItemSelected(item),
                    icon: Icon(item.icon, size: 18),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
