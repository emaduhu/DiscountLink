part of '../../../main.dart';

class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.children,
    this.padding,
    this.maxWidth = kResponsiveContentMaxWidth,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.physics,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding =
        padding?.resolve(Directionality.of(context)) ?? EdgeInsets.zero;
    return ListView(
      keyboardDismissBehavior: keyboardDismissBehavior,
      physics: physics,
      padding: EdgeInsets.only(
        top: resolvedPadding.top,
        bottom: resolvedPadding.bottom,
      ),
      children: [
        ResponsiveCenter(
          maxWidth: maxWidth,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              resolvedPadding.left,
              0,
              resolvedPadding.right,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
