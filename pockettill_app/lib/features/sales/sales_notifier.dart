import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/product.dart';
import '../../shared/repositories/product_repository.dart';
import 'cart_item.dart';
import 'sales_state.dart';

/// Owns the sale-in-progress: the cart and the live product search. Pure
/// state changes only - any resulting UI feedback (snackbars, sheets) is the
/// caller's responsibility.
class SalesNotifier extends StateNotifier<SalesState> {
  SalesNotifier(this._productRepository) : super(const SalesState());

  final ProductRepository _productRepository;

  void addToCart(Product product) {
    final items = [...state.cartItems];
    final index = items.indexWhere(
      (item) => item.product.uuid == product.uuid,
    );
    if (index >= 0) {
      items[index] = items[index].copyWith(
        quantity: items[index].quantity + 1,
      );
    } else {
      items.add(CartItem(product: product, quantity: 1));
    }
    state = state.copyWith(
      cartItems: items,
      searchQuery: '',
      searchResults: [],
    );
  }

  void removeFromCart(String productUuid) {
    state = state.copyWith(
      cartItems: state.cartItems
          .where((item) => item.product.uuid != productUuid)
          .toList(),
    );
  }

  /// Re-inserts [item] at [index] - used only to undo a just-removed item.
  void restoreCartItem(CartItem item, int index) {
    final items = [...state.cartItems];
    items.insert(index.clamp(0, items.length), item);
    state = state.copyWith(cartItems: items);
  }

  void incrementQuantity(String productUuid) {
    state = state.copyWith(
      cartItems: [
        for (final item in state.cartItems)
          if (item.product.uuid == productUuid)
            item.copyWith(quantity: item.quantity + 1)
          else
            item,
      ],
    );
  }

  /// Subtracts 1 from the item's quantity, removing it entirely once it
  /// would reach 0.
  void decrementQuantity(String productUuid) {
    final items = <CartItem>[];
    for (final item in state.cartItems) {
      if (item.product.uuid != productUuid) {
        items.add(item);
      } else if (item.quantity > 1) {
        items.add(item.copyWith(quantity: item.quantity - 1));
      }
    }
    state = state.copyWith(cartItems: items);
  }

  void clearCart() {
    state = state.copyWith(cartItems: [], searchQuery: '', searchResults: []);
  }

  Future<void> searchProducts(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        searchQuery: query,
        searchResults: [],
        isSearching: false,
      );
      return;
    }

    state = state.copyWith(searchQuery: query, isSearching: true);
    final results = await _productRepository.search(trimmed);
    // The query may have moved on again while this search was in flight -
    // discard a now-stale result rather than clobbering a newer one.
    if (state.searchQuery.trim() != trimmed) return;
    state = state.copyWith(searchResults: results, isSearching: false);
  }

  /// Looks up [barcode] and adds the match to the cart. Returns the matched
  /// product, or null if none exists - the caller decides how to surface
  /// that (e.g. an "add to stock" prompt).
  Future<Product?> onBarcodeScanned(String barcode) async {
    final product = await _productRepository.getByBarcode(barcode);
    if (product != null) {
      addToCart(product);
    }
    return product;
  }
}
