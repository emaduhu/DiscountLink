part of '../../../main.dart';

class ResponsiveSectionListView extends StatelessWidget {
  const ResponsiveSectionListView({
    super.key,
    required this.children,
    required this.menuItems,
    this.menuTitle = 'Jump to',
    this.padding,
    this.maxWidth = kResponsiveContentMaxWidth,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.physics,
  });

  final List<Widget> children;
  final List<SectionMenuItem> menuItems;
  final String menuTitle;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    if (menuItems.isEmpty) {
      return ResponsiveListView(
        maxWidth: maxWidth,
        padding: padding,
        keyboardDismissBehavior: keyboardDismissBehavior,
        physics: physics,
        children: children,
      );
    }

    final showSideMenu =
        MediaQuery.sizeOf(context).width >= kSideMenuBreakpoint;
    if (!showSideMenu) {
      return ResponsiveListView(
        maxWidth: maxWidth,
        padding: padding,
        keyboardDismissBehavior: keyboardDismissBehavior,
        physics: physics,
        children: [
          SectionJumpChips(title: menuTitle, items: menuItems),
          const SizedBox(height: 12),
          ...children,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: kSideMenuWidth,
          child: SectionSideMenu(title: menuTitle, items: menuItems),
        ),
        Expanded(
          child: ResponsiveListView(
            maxWidth: maxWidth,
            padding: padding,
            keyboardDismissBehavior: keyboardDismissBehavior,
            physics: physics,
            children: children,
          ),
        ),
      ],
    );
  }
}
