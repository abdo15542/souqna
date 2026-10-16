class CartItem {
  final Map<String, dynamic> product;
  double qty;

  CartItem({
    required this.product,
    this.qty = 1,
  });

  int get id => product['id'] as int;
  String get name => product['name'] as String? ?? 'منتج';
  double get price => (product['sale_price'] as num?)?.toDouble() ?? 0.0;
  double get cost => (product['purchase_price'] as num?)?.toDouble() ?? 0.0;

  double get lineTotal => price * qty;
  double get lineCost => cost * qty;

  Map<String, dynamic> toInvoiceMap() {
    return {
      'product_name': name,
      'qty': qty,
      'price': price,
      'total': lineTotal,
    };
  }
}
