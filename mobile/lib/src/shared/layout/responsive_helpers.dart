part of '../../../main.dart';

double responsiveMaxWidth(BuildContext context, double maxWidth) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < kTabletBreakpoint) return width;
  return width < maxWidth ? width : maxWidth;
}

int responsiveProductGridColumns(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 980) return 4;
  if (width >= 700) return 3;
  return 2;
}

double responsiveProductGridAspectRatio(BuildContext context) {
  final columns = responsiveProductGridColumns(context);
  if (columns >= 4) return 0.64;
  if (columns == 3) return 0.61;
  return 0.58;
}

void jumpToSection(GlobalKey key) {
  final context = key.currentContext;
  if (context == null) return;
  Scrollable.ensureVisible(
    context,
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    alignment: 0.03,
  );
}
