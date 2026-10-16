import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  late Future<List<Map<String, dynamic>>> _salesFuture;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  void _loadSales() {
    _salesFuture = DatabaseHelper.instance.getRecentSales(limit: 50);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرجيع')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _salesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد فواتير'));
          }
          final sales = snapshot.data!;
          return ListView.builder(
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final sale = sales[index];
              final date = (sale['created_at'] as String?)?.substring(0, 10) ?? '';
              final total = (sale['total'] as num?)?.toDouble() ?? 0.0;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.assignment_return, color: Colors.red),
                  title: Text(sale['invoice_no'] as String? ?? ''),
                  subtitle: Text('$date • ${total.toStringAsFixed(2)} د.ل'),
                  onTap: () => _showReturnDialog(context, sale['id'] as int, sale['invoice_no'] as String),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showReturnDialog(BuildContext context, int saleId, String invoiceNo) async {
    final items = await DatabaseHelper.instance.getSaleItems(saleId);
    if (!mounted) return;
    
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كل العناصر مُرجَّعة مسبقًا'))
      );
      return;
    }

    final selected = <int>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('اختر عناصر للرجيع - $invoiceNo'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StatefulBuilder(
            builder: (ctx, setState) => ListView(
              children: items.map((item) {
                final id = item['id'] as int;
                final name = item['product_name'] as String? ?? '';
                final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                return CheckboxListTile(
                  value: selected.contains(id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        selected.add(id);
                      } else {
                        selected.remove(id);
                      }
                    });
                  },
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
            child: const Text('تأكيد الرجيع')
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DatabaseHelper.instance.processReturn(
          saleId: saleId,
          itemIds: selected.toList(),
          reason: 'رجيع يدوي',
        );
        _loadSales();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إرجاع ${selected.length} عنصر'))
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }
}
