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

    final showFullSideMenu =
        MediaQuery.sizeOf(context).width >= kSideMenuBreakpoint;
    if (!showFullSideMenu) {
      return Stack(
        children: [
          ResponsiveListView(
            maxWidth: maxWidth,
            padding: padding,
            keyboardDismissBehavior: keyboardDismissBehavior,
            physics: physics,
            children: children,
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _phoneSectionMenuButton(context, menuTitle, menuItems),
            ),
          ),
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

Widget _phoneSectionMenuButton(
  BuildContext context,
  String title,
  List<SectionMenuItem> items,
) {
  return Material(
    color: kPrimaryColor,
    elevation: 8,
    borderRadius: BorderRadius.circular(16),
    child: IconButton(
      tooltip: title,
      onPressed: () => _showPhoneSectionMenu(context, title, items),
      icon: const Icon(Icons.menu_open_rounded),
      color: Colors.white,
    ),
  );
}

Future<void> _showPhoneSectionMenu(
  BuildContext context,
  String title,
  List<SectionMenuItem> items,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, _) {
      final width = MediaQuery.sizeOf(dialogContext).width;
      final drawerWidth = width >= 360 ? 280.0 : width * 0.84;
      return Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: drawerWidth,
            height: double.infinity,
            child: SectionSideMenu(
              title: title,
              items: items,
              onItemSelected: (item) {
                Navigator.of(dialogContext).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  jumpToSection(item.key);
                });
              },
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, _, child) {
      final position = Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: position, child: child);
    },
  );
}
