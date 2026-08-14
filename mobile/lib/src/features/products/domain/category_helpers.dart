part of '../../../../main.dart';

const defaultShopCategories = [
  'Electronics',
  'Fashion',
  'Groceries',
  'Books',
  'Art',
  'Home',
  'Other',
];

List<CategoryView> categoryViewsFromNames(List<String> categories) => [
  for (final category in categories)
    CategoryView(category, categoryIcon(category)),
];

IconData categoryIcon(String category) {
  final normalized = category.toLowerCase();
  if (normalized.contains('elect')) return Icons.devices_other;
  if (normalized.contains('fashion') || normalized.contains('cloth')) {
    return Icons.checkroom_outlined;
  }
  if (normalized.contains('grocery') || normalized.contains('food')) {
    return Icons.local_grocery_store_outlined;
  }
  if (normalized.contains('book')) return Icons.menu_book_outlined;
  if (normalized.contains('art')) return Icons.palette_outlined;
  if (normalized.contains('home')) return Icons.home_outlined;
  if (normalized.contains('beauty')) return Icons.spa_outlined;
  if (normalized.contains('sport')) return Icons.sports_soccer_outlined;
  return Icons.category_outlined;
}
