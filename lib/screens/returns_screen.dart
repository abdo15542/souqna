import 'package:flutter/material.dart';

import '../db/database_helper.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getRecentSales();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرجيع / المرتجعات')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final sales = snap.data!;
          if (sales.isEmpty) {
            return const Center(child: Text('لا توجد فواتير'));
          }
          return ListView.builder(
            itemCount: sales.length,
            itemBuilder: (_, i) {
              final s = sales[i];
              final date = (s['created_at'] as String?)?.substring(0, 10) ?? '';
              final total = (s['total'] as num?)?.toDouble() ?? 0.0;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.assignment_return, color: Colors.red),
                  title: Text(s['invoice_no'] as String? ?? ''),
                  subtitle: Text('$date • ${total.toStringAsFixed(2)} د.ل'),
                  onTap: () => _pickItems(s['id'] as int, s['invoice_no'] as String),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pickItems(int saleId, String invNo) async {
    final items = await DatabaseHelper.instance.getSaleItems(saleId);
    if (!mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('كل عناصر هذه الفاتورة مُرجَّعة مسبقًا')));
      return;
    }
    final selected = <int>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('اختر العناصر المرتجعة — $invNo'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: ListView(
            children: items.map((it) {
              final id = it['id'] as int;
              final name = it['product_name'] as String? ?? '';
              final qty = (it['qty'] as num?)?.toDouble() ?? 0.0;
              final price = (it['price'] as num?)?.toDouble() ?? 0.0;
              return CheckboxListTile(
                value: selected.contains(id),
                onChanged: (v) {
                  if (v == true) {
                    selected.add(id);
                  } else {
                    selected.remove(id);
                  }
                  Navigator.pop(ctx); // أغلق وأعيد فتح لتحديث الحالة ببساطة
                  _reopenPick(ctx, saleId, invNo, selected);
                },
                title: Text(name),
                subtitle: Text('${qty.toStringAsFixed(0)} × ${price.toStringAsFixed(2)}'),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, selected.isNotEmpty),
            child: const Text('تأكيد الرجيع'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await DatabaseHelper.instance.processReturn(
        saleId: saleId,
        itemIds: selected.toList(),
        reason: 'رجيع يدوي',
      );
      if (!mounted) return;
      setState(() => _future = DatabaseHelper.instance.getRecentSales());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم إرجاع ${selected.length} عنصر لفاتورة $invNo')));
    }
  }

  void _reopenPick(BuildContext ctx, int saleId, String invNo, Set<int> sel) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Navigator.canPop(ctx)) Navigator.pop(ctx);
      _pickItemsReloaded(saleId, invNo, sel);
    });
  }

  Future<void> _pickItemsReloaded(int saleId, String invNo, Set<int> preSelected) async {
    final items = await DatabaseHelper.instance.getSaleItems(saleId);
    if (!mounted) return;
    final selected = <int>{...preSelected};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('اختر العناصر المرتجعة — $invNo'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: StatefulBuilder(
            builder: (ctx, setSt) => ListView(
              children: items.map((it) {
                final id = it['id'] as int;
                final name = it['product_name'] as String? ?? '';
                final qty = (it['qty'] as num?)?.toDouble() ?? 0.0;
                final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                return CheckboxListTile(
                  value: selected.contains(id),
                  onChanged: (v) => setSt(() {
                    if (v == true) {
                      selected.add(id);
                    } else {
                      selected.remove(id);
                    }
                  }),
                  title: Text(name),
                  subtitle: Text('${qty.toStringAsFixed(0)} × ${price.toStringAsFixed(2)}'),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, selected.isNotEmpty),
            child: const Text('تأكيد الرجيع'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await DatabaseHelper.instance.processReturn(
        saleId: saleId,
        itemIds: selected.toList(),
        reason: 'رجيع يدوي',
      );
      if (!mounted) return;
      setState(() => _future = DatabaseHelper.instance.getRecentSales());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم إرجاع ${selected.length} عنصر لفاتورة $invNo')));
    }
  }
}
