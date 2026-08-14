part of '../../../../../main.dart';

class CategoryMultiSelect extends StatelessWidget {
  const CategoryMultiSelect({
    super.key,
    required this.categories,
    required this.selected,
    required this.onChanged,
  });
  final List<String> categories;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Shop categories',
          prefixIcon: Icon(Icons.category_outlined),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final category in categories)
              FilterChip(
                label: Text(category),
                selected: selected.contains(category),
                onSelected: (checked) {
                  final next = {...selected};
                  if (checked) {
                    next.add(category);
                  } else if (next.length > 1) {
                    next.remove(category);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
      ),
    );
  }
}
