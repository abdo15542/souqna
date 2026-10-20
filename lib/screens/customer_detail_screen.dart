import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../db/database_helper.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailScreen({super.key, required this.customerId});
  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _ledger = [];
  bool _loading = true;
  double _balance = 0.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await DatabaseHelper.instance.getCustomer(widget.customerId);
    final entries = await DatabaseHelper.instance.getLedger(widget.customerId);
    if (!mounted) return;
    setState(() {
      _customer = c;
      _ledger = entries;
      _balance = entries.fold<double>(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
      _loading = false;
    });
  }

  // ================= Record Payment / Debt =================
  Future<void> _recordTransaction(bool isPayment) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? dueDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(isPayment ? 'تسجيل دفعة' : 'إضافة دين'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amountCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: isPayment ? 'قيمة الدفعة (د.ل)' : 'قيمة الدين (د.ل)')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
          if (!isPayment) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) dueDate = picked.toIso8601String().substring(0, 10);
              },
              icon: const Icon(Icons.event_rounded),
              label: Text(dueDate == null ? 'حدد تاريخ الاستحقاق' : 'الاستحقاق: $dueDate'),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: isPayment ? AppColors.success : AppColors.danger),
            onPressed: () {
              final v = double.tryParse(amountCtrl.text.trim());
              if (v == null || v <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('أدخل قيمة صحيحة أكبر من صفر')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final amount = double.parse(amountCtrl.text.trim());
      final signedAmount = isPayment ? -amount : amount;
      await DatabaseHelper.instance.addLedgerEntry(
        customerId: widget.customerId,
        amount: signedAmount,
        kind: isPayment ? 'دفعة' : 'دين',
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        dueDate: isPayment ? null : dueDate,
      );
      _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isPayment ? '✓ تم تسجيل الدفعة' : '✓ تم إضافة الدين'),
        backgroundColor: isPayment ? AppColors.success : AppColors.warning,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('تفاصيل الزبون')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_customer == null) {
      return Scaffold(appBar: AppBar(title: const Text('تفاصيل الزبون')), body: const EmptyState(message: 'الزبون غير موجود'));
    }
    final name = _customer!['name'] as String? ?? '';
    final phone = _customer!['phone'] as String? ?? '';
    final hasDebt = _balance > 0.009;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(heroTag: 'pay', onPressed: () => _recordTransaction(true), backgroundColor: AppColors.success, foregroundColor: Colors.white, icon: const Icon(Icons.payments_rounded), label: const Text('دفعة')),
          const SizedBox(width: AppSpacing.md),
          FloatingActionButton.extended(heroTag: 'debt', onPressed: () => _recordTransaction(false), backgroundColor: AppColors.danger, foregroundColor: Colors.white, icon: const Icon(Icons.add_card_rounded), label: const Text('دين')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ===== بطاقة الرصيد =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: hasDebt ? AppColors.danger.withOpacity(0.10) : AppColors.success.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: softShadow(hasDebt ? AppColors.danger : AppColors.success),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(hasDebt ? Icons.account_balance_wallet_rounded : Icons.check_circle_rounded, color: hasDebt ? AppColors.danger : AppColors.success, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Text(hasDebt ? 'عليه مبلغ' : 'الرصيد مسدد', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: hasDebt ? AppColors.danger : AppColors.success)),
              ]),
              const SizedBox(height: AppSpacing.md),
              Text('${_balance.toStringAsFixed(2)} د.ل', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: hasDebt ? AppColors.danger : AppColors.success)),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  const Icon(Icons.phone_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(phone, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
          // ===== سجل المعاملات =====
          SectionCard(
            title: 'سجل المعاملات (${_ledger.length})',
            accent: AppColors.seed,
            children: _ledger.isEmpty
                ? [Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), child: Text('لا توجد معاملات بعد.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)))]
                : _ledger.map((e) {
                    final amount = (e['amount'] as num?)?.toDouble() ?? 0.0;
                    final isPay = amount < 0;
                    final date = (e['created_at'] as String?)?.substring(0, 10) ?? '';
                    final kind = e['kind'] as String? ?? '';
                    final note = e['note'] as String? ?? '';
                    final due = e['due_date'] as String?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm + 2),
                        decoration: BoxDecoration(
                          color: isPay ? AppColors.success.withOpacity(0.06) : AppColors.danger.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(color: isPay ? AppColors.success.withOpacity(0.2) : AppColors.danger.withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          CircleAvatar(radius: 18, backgroundColor: isPay ? AppColors.success.withOpacity(0.15) : AppColors.danger.withOpacity(0.15), child: Icon(isPay ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: isPay ? AppColors.success : AppColors.danger, size: 20)),
                          const SizedBox(width: AppSpacing.sm + 2),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(kind, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(date + (note.isNotEmpty ? ' • $note' : ''), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            if (due != null) Text('يستحق: $due', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
                          ])),
                          Text('${amount.abs().toStringAsFixed(2)} د.ل', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: isPay ? AppColors.success : AppColors.danger)),
                        ]),
                      ),
                    );
                  }).toList(),
          ),
        ],
      ),
    );
  }
}
