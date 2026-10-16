import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  double _total = 0;
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
    final customers = await DatabaseHelper.instance.getCustomers(
      search: _searchController.text,
    );
    final total = await DatabaseHelper.instance.totalOutstanding();

    if (!mounted) return;
    setState(() {
      _customers = customers;
      _total = total;
      _loading = false;
    });
  }

  Future<void> _showCustomerDialog({Map<String, dynamic>? customer}) async {
    final nameController = TextEditingController(text: customer?['name'] ?? '');
    final phoneController = TextEditingController(text: customer?['phone'] ?? '');
    final addressController = TextEditingController(text: customer?['address'] ?? '');
    final notesController = TextEditingController(text: customer?['notes'] ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(customer == null ? 'زبون جديد' : 'تعديل زبون'),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
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

    if (ok != true) return;

    final data = {
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'address': addressController.text.trim(),
      'notes': notesController.text.trim(),
    };

    if (customer == null) {
      await DatabaseHelper.instance.insertCustomer(data);
    } else {
      await DatabaseHelper.instance.updateCustomer(
        customer['id'] as int,
        data,
      );
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الذمم')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('زبون جديد'),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'إجمالي الذمم المستحقة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_total.toStringAsFixed(2)} د.ل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الهاتف',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const Center(child: Text('لا يوجد زبائن'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _customers.length,
                        itemBuilder: (_, index) {
                          final c = _customers[index];
                          final balance =
                              (c['balance'] as num?)?.toDouble() ?? 0;
                          final overdue = c['overdue'] == true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                overdue ? Icons.warning_amber : Icons.person,
                                color: overdue ? Colors.red : Colors.blueGrey,
                              ),
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerDetailScreen(
                                      customerId: c['id'] as int,
                                      customerName: c['name'] as String,
                                    ),
                                  ),
                                ).then((_) => _load());
                              },
                              onLongPress: () => _showCustomerDialog(customer: c),
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

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  final String customerName;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _ledger = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final customer = await DatabaseHelper.instance.getCustomer(widget.customerId);
    final ledger = await DatabaseHelper.instance.getLedger(widget.customerId);

    if (!mounted) return;
    setState(() {
      _customer = customer;
      _ledger = ledger;
      _loading = false;
    });
  }

  double get balance {
    return _ledger.fold<double>(0, (sum, e) => sum + ((e['amount'] as num).toDouble()));
  }

  Future<void> _showEntrySheet() async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String kind = 'دين';
    String? dueDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'حركة جديدة لـ ${widget.customerName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'دين', label: Text('دين')),
                      ButtonSegment(value: 'دفعة', label: Text('دفعة')),
                    ],
                    selected: {kind},
                    onSelectionChanged: (s) => setSheet(() => kind = s.first),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (kind == 'دين')
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تاريخ الاستحقاق'),
                      subtitle: Text(dueDate ?? 'غير محدد'),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setSheet(() {
                            dueDate = picked.toIso8601String().substring(0, 10);
                          });
                        }
                      },
                    ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text.trim());
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('المبلغ غير صحيح')),
                        );
                        return;
                      }

                      final signed = kind == 'دفعة' ? -amount : amount;

                      await DatabaseHelper.instance.addLedgerEntry(
                        customerId: widget.customerId,
                        amount: signed,
                        kind: kind,
                        note: noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                        dueDate: kind == 'دين' ? dueDate : null,
                      );

                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      await _load();
                    },
                    child: const Text('حفظ'),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return Scaffold(
      appBar: AppBar(title: Text(widget.customerName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEntrySheet,
        icon: const Icon(Icons.add),
        label: const Text('حركة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: balance > 0 ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الرصيد',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        '${balance.toStringAsFixed(2)} د.ل',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: balance > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _ledger.isEmpty
                      ? const Center(child: Text('لا توجد حركات'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _ledger.length,
                          itemBuilder: (_, index) {
                            final e = _ledger[index];
                            final amount = (e['amount'] as num).toDouble();
                            final kind = e['kind'] as String;
                            final due = e['due_date'] as String?;
                            final isOverdue =
                                amount > 0 && due != null && due <= today;

                            final created = DateTime.tryParse(
                                  e['created_at'] as String,
                                ) ??
                                DateTime.now();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  amount >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: amount >= 0 ? Colors.red : Colors.green,
                                ),
                                title: Text(kind),
                                subtitle: Text(
                                  '${DateFormat('yyyy/MM/dd HH:mm').format(created)}'
                                  '${due != null ? '\nالاستحقاق: $due' : ''}'
                                  '${e['note'] != null ? '\n${e['note']}' : ''}',
                                ),
                                trailing: Text(
                                  '${amount.abs().toStringAsFixed(2)} د.ل',
                                  style: TextStyle(
                                    color: amount >= 0 ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                tileColor: isOverdue ? Colors.red.shade50 : null,
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
