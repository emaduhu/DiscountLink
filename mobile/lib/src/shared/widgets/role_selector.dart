part of '../../../main.dart';

class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const roles = [
      ('buyer', 'Buyer', Icons.shopping_bag_outlined),
      ('seller', 'Seller', Icons.storefront_outlined),
      ('deliverer', 'Deliverer', Icons.delivery_dining_outlined),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in roles)
          ChoiceChip(
            selected: value == role.$1,
            label: Text(role.$2),
            avatar: Icon(role.$3, size: 18),
            selectedColor: appPrimarySoftColor(context),
            checkmarkColor: kPrimaryColor,
            onSelected: (_) => onChanged(role.$1),
          ),
      ],
    );
  }
}
