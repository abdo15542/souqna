import 'package:flutter/material.dart';

import '../db/database_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await DatabaseHelper.instance.getProducts(
      search: _searchController.text,
    );
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _showForm({Map<String, dynamic>? product}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: ProductFormSheet(product: product),
      ),
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: const Text('هل تريد حذف هذا المنتج من القائمة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await DatabaseHelper.instance.softDeleteProduct(id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المخزون')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('منتج جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('لا توجد منتجات'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _products.length,
                        itemBuilder: (_, index) {
                          final p = _products[index];
                          final qty = (p['quantity'] as num?)?.toDouble() ?? 0;
                          final low = (p['low_stock'] as num?)?.toDouble() ?? 0;
                          final isLow = qty <= low;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(p['name'] as String),
                              subtitle: Text(
                                'شراء: ${(p['purchase_price'] as num).toStringAsFixed(2)} | بيع: ${(p['sale_price'] as num).toStringAsFixed(2)} د.ل',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      qty.toStringAsFixed(0),
                                      style: TextStyle(
                                        color: isLow ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _showForm(product: p);
                                      if (v == 'delete') _delete(p['id'] as int);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () => _showForm(product: p),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class ProductFormSheet extends StatefulWidget {
  final Map<String, dynamic>? product;

  const ProductFormSheet({super.key, this.product});

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  int _step = 0;

  late final TextEditingController _name;
  late final TextEditingController _salePrice;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _quantity;
  late final TextEditingController _lowStock;
  late final TextEditingController _barcode;
  late final TextEditingController _category;

  @override
  void initState() {
    super.initState();

    final p = widget.product;

    _name = TextEditingController(text: p?['name']?.toString() ?? '');
    _salePrice = TextEditingController(text: (p?['sale_price'] ?? 0).toString());
    _purchasePrice = TextEditingController(text: (p?['purchase_price'] ?? 0).toString());
    _quantity = TextEditingController(text: (p?['quantity'] ?? 0).toString());
    _lowStock = TextEditingController(text: (p?['low_stock'] ?? 5).toString());
    _barcode = TextEditingController(text: p?['barcode']?.toString() ?? '');
    _category = TextEditingController(text: p?['category']?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _salePrice.dispose();
    _purchasePrice.dispose();
    _quantity.dispose();
    _lowStock.dispose();
    _barcode.dispose();
    _category.dispose();
    super.dispose();
  }

  bool _validateStep0() {
    if (_name.text.trim().isEmpty) {
      _msg('اسم المنتج مطلوب');
      return false;
    }

    final sale = double.tryParse(_salePrice.text.trim());
    final purchase = double.tryParse(_purchasePrice.text.trim());
    final qty = double.tryParse(_quantity.text.trim());

    if (sale == null || sale < 0) {
      _msg('سعر البيع غير صحيح');
      return false;
    }
    if (purchase == null || purchase < 0) {
      _msg('سعر الشراء غير صحيح');
      return false;
    }
    if (qty == null || qty < 0) {
      _msg('الكمية غير صحيحة');
      return false;
    }

    return true;
  }

  Future<void> _save() async {
    final double sale = double.tryParse(_salePrice.text.trim()) ?? 0.0;
    final double purchase = double.tryParse(_purchasePrice.text.trim()) ?? 0.0;
    final double qty = double.tryParse(_quantity.text.trim()) ?? 0.0;
    final double low = double.tryParse(_lowStock.text.trim()) ?? 5.0;

    final data = {
      'name': _name.text.trim(),
      'sale_price': sale,
      'purchase_price': purchase,
      'quantity': qty,
      'low_stock': low,
      'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      'category': _category.text.trim().isEmpty ? null : _category.text.trim(),
    };

    if (widget.product == null) {
      data['active'] = 1;
      await DatabaseHelper.instance.insertProduct(data);
    } else {
      await DatabaseHelper.instance.updateProduct(
        widget.product!['id'] as int,
        data,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Stepper(
        currentStep: _step,
        type: StepperType.horizontal,
        onStepContinue: () {
          if (_step == 0) {
            if (_validateStep0()) {
              setState(() => _step = 1);
            }
          } else {
            _save();
          }
        },
        onStepCancel: () {
          if (_step > 0) {
            setState(() => _step -= 1);
          } else {
            Navigator.pop(context, false);
          }
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              FilledButton(
                onPressed: details.onStepContinue,
                child: Text(_step == 0 ? 'التالي' : 'حفظ'),
              ),
              const SizedBox(width: 10),
              if (_step > 0)
                OutlinedButton(
                  onPressed: details.onStepCancel,
                  child: const Text('السابق'),
                ),
            ],
          );
        },
        steps: [
          Step(
            title: const Text('الأساسيات'),
            isActive: _step >= 0,
            content: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _salePrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر البيع *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _purchasePrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر الشراء *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'الكمية *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('تنبيهات'),
            isActive: _step >= 1,
            content: Column(
              children: [
                TextField(
                  controller: _lowStock,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'حد التنبيه عند انخفاض الكمية',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _barcode,
                  decoration: const InputDecoration(
                    labelText: 'الباركود (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _category,
                  decoration: const InputDecoration(
                    labelText: 'التصنيف (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
