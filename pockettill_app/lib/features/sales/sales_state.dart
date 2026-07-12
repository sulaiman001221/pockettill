import '../../shared/models/product.dart';
import 'cart_item.dart';

/// Immutable state for the in-progress sale: the cart, and the live product
/// search happening in the search bar.
class SalesState {
  const SalesState({
    this.cartItems = const [],
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
  });

  final List<CartItem> cartItems;
  final String searchQuery;
  final List<Product> searchResults;
  final bool isSearching;

  /// Sum of every cart item's subtotal - always derived, never stored, so it
  /// can never drift out of sync with [cartItems].
  double get cartTotal =>
      cartItems.fold(0, (sum, item) => sum + item.subtotal);

  SalesState copyWith({
    List<CartItem>? cartItems,
    String? searchQuery,
    List<Product>? searchResults,
    bool? isSearching,
  }) {
    return SalesState(
      cartItems: cartItems ?? this.cartItems,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}
