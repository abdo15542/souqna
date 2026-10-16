import '../services/print_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/models.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _paidController = TextEditingController(text: '0');

  List<Map<String, dynamic>> _products = [];
  final Map<int, CartItem> _cart = {};

  Map<String, dynamic>? _customer;
  String _paymentMethod = 'نقدي';
  double _discount = 0;
  double _paid = 0;
  bool _loading = true;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _discountController.addListener(_syncDiscount);
    _paidController.addListener(_syncPaid);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  void _syncDiscount() {
    setState(() {
      _discount = double.tryParse(_discountController.text.trim()) ?? 0;
    });
  }

  void _syncPaid() {
    setState(() {
      _paid = double.tryParse(_paidController.text.trim()) ?? 0;
    });
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getProducts(
      search: _searchController.text,
    );
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  double get subtotal =>
      _cart.values.fold<double>(0, (sum, item) => sum + item.lineTotal);

  double get total {
    final double d = _discount < 0 ? 0.0 : _discount;
    final double t = subtotal - d;
    return t < 0 ? 0.0 : t;
  }

  double get change => _paid > total ? _paid - total : 0.0;
  double get debt => total > _paid ? total - _paid : 0.0;

  void _addToCart(Map<String, dynamic> product) {
    final double stock = (product['quantity'] as num?)?.toDouble() ?? 0.0;
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الكمية غير متوفرة')),
      );
      return;
    }

    final id = product['id'] as int;
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!.qty += 1;
      } else {
        _cart[id] = CartItem(product: product);
      }
    });
  }

  void _changeQty(CartItem item, double delta) {
    setState(() {
      item.qty += delta;
      if (item.qty <= 0) {
        _cart.remove(item.id);
      }
    });
  }

  Future<void> _pickCustomer() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.getCustomers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final customers = snapshot.data!;

              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_add),
                    title: const Text('إضافة زبون جديد'),
                    onTap: () async {
                      final newCustomer = await _addCustomerDialog();
                      if (newCustomer != null && sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                        setState(() => _customer = newCustomer);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: customers.length,
                      itemBuilder: (_, index) {
                        final c = customers[index];
                        final balance =
                            (c['balance'] as num?)?.toDouble() ?? 0;
                        final overdue = c['overdue'] == true;

                        return ListTile(
                          title: Text(c['name'] as String),
                          subtitle: Text(
                            c['phone']?.toString().isNotEmpty == true
                                ? c['phone'].toString()
                                : 'بدون هاتف',
                          ),
                          trailing: Text(
                            '${balance.toStringAsFixed(2)} د.ل',
                            style: TextStyle(
                              color: balance > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            setState(() => _customer = c);
                          },
                          leading: Icon(
                            overdue ? Icons.warning_amber : Icons.person,
                            color: overdue ? Colors.red : Colors.blueGrey,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _addCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('زبون جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'الاسم *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'الهاتف'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('الاسم مطلوب')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    if (ok != true) return null;

    final id = await DatabaseHelper.instance.insertCustomer({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
    });

    return DatabaseHelper.instance.getCustomer(id);
  }

  Future<void> _saveSale() async {
    if (_cart.isEmpty) {
      _msg('السلة فارغة');
      return;
    }

    final items = _cart.values.toList();
    final double effectiveDiscount = _discount < 0 ? 0.0 : _discount;
    final double saleSubtotal = subtotal;
    final double saleTotal = total;
    final double salePaid = _paid < 0 ? 0.0 : _paid;
    final double saleChange = change;
    final double saleDebt = debt;
    final customerName = _customer?['name'] as String?;
    final paymentMethod = _paymentMethod;

    if (saleDebt > 0.009 && _customer == null) {
      _msg('اختر زبوناً لتسجيل الدين');
      return;
    }

    try {
      final result = await DatabaseHelper.instance.saveSale(
        items: items,
        discount: effectiveDiscount,
        paid: salePaid,
        paymentMethod: paymentMethod,
        customerId: _customer?['id'] as int?,
      );

      final invoiceNo = result['invoice_no'] as String;
      final saleId = result['id'] as int;

      setState(() {
        _cart.clear();
        _customer = null;
        _paymentMethod = 'نقدي';
        _discount = 0;
        _paid = 0;
        _discountController.text = '0';
        _paidController.text = '0';
      });

      await _loadProducts();

      if (!mounted) return;

      final printNow = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('تم حفظ الفاتورة'),
            content: Text('رقم الفاتورة: $invoiceNo\nهل تريد طباعتها الآن؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('لاحقاً'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('طباعة'),
              ),
            ],
          );
        },
      );

      if (printNow == true) {
        final error = await PrintService.printInvoice(
          invoiceNo: invoiceNo,
          date: DateTime.now(),
          customerName: customerName,
          items: items.map((e) => e.toInvoiceMap()).toList(),
          subtotal: saleSubtotal,
          discount: effectiveDiscount,
          total: saleTotal,
          paid: salePaid,
          change: saleChange,
          debt: saleDebt,
          paymentMethod: paymentMethod,
        );

        if (!mounted) return;

        if (error == null) {
          await DatabaseHelper.instance.markPrinted(saleId);
          _msg('تمت الطباعة بنجاح');
        } else {
          _msg(error);
        }
      } else {
        _msg('تم حفظ الفاتورة');
      }
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بيع جديد'),
        actions: [
          IconButton(
            onPressed: _saveSale,
            icon: const Icon(Icons.save),
            tooltip: 'حفظ الفاتورة',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المنتجات'),
            Tab(text: 'السلة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _productsTab(),
          _cartTab(),
        ],
      ),
      floatingActionButton: _cart.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.shopping_cart),
              label: Text('${_cart.length} منتج'),
            ),
    );
  }

  Widget _productsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: (_) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), _loadProducts);
            },
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الباركود',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Expanded(
          child: _products.isEmpty
              ? const Center(child: Text('لا توجد منتجات'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _products.length,
                  itemBuilder: (_, index) {
                    final p = _products[index];
                    final double stock = (p['quantity'] as num?)?.toDouble() ?? 0.0;
                    final double price = (p['sale_price'] as num?)?.toDouble() ?? 0.0;
                    final double lowStock = (p['low_stock'] as num?)?.toDouble() ?? 0.0;
                    final bool low = stock <= lowStock || stock <= 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        enabled: stock > 0,
                        title: Text(p['name'] as String),
                        subtitle: Text(
                          'السعر: ${price.toStringAsFixed(2)} د.ل | المتوفر: ${stock.toStringAsFixed(0)}',
                          style: TextStyle(color: low ? Colors.red : null),
                        ),
                        trailing: const Icon(Icons.add_circle, size: 32),
                        onTap: stock > 0 ? () => _addToCart(p) : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _cartTab() {
    final items = _cart.values.toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        InkWell(
          onTap: _pickCustomer,
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(_customer?['name'] ?? 'زبون نقدي / بدون ذمة'),
              subtitle: Text(
                debt > 0 && _customer == null
                    ? 'يجب اختيار زبون لتسجيل الدين'
                    : 'اضغط لاختيار زبون',
                style: TextStyle(
                  color: debt > 0 && _customer == null ? Colors.red : null,
                ),
              ),
              trailing: const Icon(Icons.edit),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: const [
                DropdownMenuItem(value: 'نقدي', child: Text('نقدي')),
                DropdownMenuItem(value: 'آجل', child: Text('آجل')),
                DropdownMenuItem(value: 'تحويل', child: Text('تحويل')),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v ?? 'نقدي'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'خصم',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _paidController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المدفوع',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('السلة فارغة')),
            ),
          )
        else
          ...items.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.name),
                subtitle: Text(
                  '${item.price.toStringAsFixed(2)} د.ل × ${item.qty.toStringAsFixed(item.qty % 1 == 0 ? 0 : 2)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _changeQty(item, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(item.qty.toStringAsFixed(0)),
                    IconButton(
                      onPressed: () => _changeQty(item, 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _cart.remove(item.id)),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _totalRow('الإجمالي', subtotal),
                _totalRow('الخصم', _discount),
                _totalRow('الصافي', total, bold: true),
                _totalRow('المدفوع', _paid),
                if (change > 0) _totalRow('الباقي', change),
                if (debt > 0) _totalRow('الدين', debt, color: Colors.red),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saveSale,
          icon: const Icon(Icons.save),
          label: const Text('حفظ الفاتورة'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _totalRow(
    String label,
    double value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
          ),
          Text(
            '${value.toStringAsFixed(2)} د.ل',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : null,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
