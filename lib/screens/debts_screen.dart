import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../db/database_helper.dart';
import 'customer_detail_screen.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});
  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _future = DatabaseHelper.instance.getCustomers(search: _query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الذمم')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_customer',
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('زبون جديد'),
        backgroundColor: AppColors.seed,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SearchField(
              hint: 'ابحث بالاسم أو الهاتف',
              onChanged: (v) {
                setState(() => _query = v);
                _load();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const EmptyState(
                    message: 'لا يوجد زبائن مسجلون بعد.\nاضغط «زبون جديد» لإضافة أول زبون.',
                    icon: Icons.people_outline_rounded,
                  );
                }
                final customers = snapshot.data!;
                return ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final c = customers[index];
                    final balance = (c['balance'] as num?)?.toDouble() ?? 0.0;
                    final overdue = c['overdue'] == true;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm / 2),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: overdue ? AppColors.danger.withOpacity(0.12) : AppColors.seed.withOpacity(0.12),
                          child: Icon(Icons.person_rounded, color: overdue ? AppColors.danger : AppColors.seed),
                        ),
                        title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        subtitle: Text(c['phone'] as String? ?? '', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${balance.toStringAsFixed(2)} د.ل',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: balance > 0 ? AppColors.danger : AppColors.success,
                                )),
                            if (overdue)
                              const Text('متأخر', style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: c['id'] as int)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة زبون جديد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم *')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الاسم مطلوب')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await DatabaseHelper.instance.insertCustomer({
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      });
      _load();
    }
  }
}
