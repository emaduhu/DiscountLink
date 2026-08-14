part of '../../../main.dart';

class MarketplaceHeader extends StatelessWidget {
  const MarketplaceHeader({
    super.key,
    required this.search,
    required this.onSearch,
    required this.cartCount,
    required this.cartLoading,
    required this.onCart,
  });
  final TextEditingController search;
  final VoidCallback onSearch;
  final int cartCount;
  final bool cartLoading;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: search,
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              hintText: 'Search products',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed: onSearch,
          style: IconButton.styleFrom(
            backgroundColor: kPrimaryColor,
            fixedSize: const Size(52, 52),
          ),
          icon: const Icon(Icons.search),
        ),
        const SizedBox(width: 10),
        Badge(
          label: Text('$cartCount'),
          isLabelVisible: cartCount > 0 && !cartLoading,
          child: IconButton(
            onPressed: onCart,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              fixedSize: const Size(52, 52),
            ),
            icon: cartLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shopping_cart_outlined),
          ),
        ),
      ],
    );
  }
}
