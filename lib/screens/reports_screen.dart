import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../db/database_helper.dart';
import 'returns_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _range = 0;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  Map<String, dynamic> _report = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _setPresetRange(0);
    _load();
  }

  void _setPresetRange(int value) {
    final now = DateTime.now();
    if (value == 0) {
      _start = DateTime(now.year, now.month, now.day);
      _end = _start;
    } else if (value == 1) {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      _start = DateTime(monday.year, monday.month, monday.day);
      _end = DateTime(now.year, now.month, now.day);
    } else if (value == 2) {
      _start = DateTime(now.year, now.month, 1);
      _end = DateTime(now.year, now.month + 1, 0);
    }
    _range = value;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await DatabaseHelper.instance.getReport(_start, _end);
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<void> _onRangeChanged(int value) async {
    if (value == 3) {
      final picked = await showDateRangePicker(
          context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
      if (picked == null) return;
      setState(() {
        _range = value;
        _start = picked.start;
        _end = picked.end;
      });
    } else {
      setState(() => _setPresetRange(value));
    }
    await _load();
  }

  String _csv() {
    final revenue = (_report['revenue'] as num?)?.toDouble() ?? 0.0;
    final profit = (_report['profit'] as num?)?.toDouble() ?? 0.0;
    final invoices = (_report['invoices'] as num?)?.toInt() ?? 0;
    final credit = (_report['credit'] as num?)?.toDouble() ?? 0.0;
    final top = (_report['top'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final b = StringBuffer();
    b.writeln('تقرير سوقنا');
    b.writeln('من,${_start.toIso8601String().substring(0, 10)}');
    b.writeln('إلى,${_end.toIso8601String().substring(0, 10)}');
    b.writeln('عدد الفواتير,$invoices');
    b.writeln('المبيعات,${revenue.toStringAsFixed(2)}');
    b.writeln('الأرباح,${profit.toStringAsFixed(2)}');
    b.writeln('الآجل,${credit.toStringAsFixed(2)}');
    b.writeln('');
    b.writeln('المنتج,الكمية,الإيراد');
    for (final p in top) {
      b.writeln('${p['product_name']},${(p['qty'] as num).toStringAsFixed(0)},${(p['revenue'] as num).toStringAsFixed(2)}');
    }
    return b.toString();
  }

  void _showCsv() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('تصدير CSV (انسخ النص)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: SelectableText(_csv(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final revenue = (_report['revenue'] as num?)?.toDouble() ?? 0.0;
    final profit = (_report['profit'] as num?)?.toDouble() ?? 0.0;
    final invoices = (_report['invoices'] as num?)?.toInt() ?? 0;
    final credit = (_report['credit'] as num?)?.toDouble() ?? 0.0;
    final top = (_report['top'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(onPressed: _showCsv, icon: const Icon(Icons.table_view_rounded), tooltip: 'تصدير CSV'),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnsScreen())),
            icon: const Icon(Icons.assignment_return_rounded),
            tooltip: 'الرجيع',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('اليوم')),
                    ButtonSegment(value: 1, label: Text('الأسبوع')),
                    ButtonSegment(value: 2, label: Text('الشهر')),
                    ButtonSegment(value: 3, label: Text('مخصص')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => _onRangeChanged(s.first),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(spacing: AppSpacing.sm + 2, runSpacing: AppSpacing.sm + 2, children: [
                  _metric('المبيعات', '${revenue.toStringAsFixed(2)} د.ل', Icons.attach_money_rounded, AppColors.seed),
                  _metric('الأرباح', '${profit.toStringAsFixed(2)} د.ل', Icons.trending_up_rounded, AppColors.success),
                  _metric('الفواتير', '$invoices', Icons.receipt_long_rounded, AppColors.info),
                  _metric('الآجل في الفترة', '${credit.toStringAsFixed(2)} د.ل', Icons.credit_score_rounded, AppColors.danger),
                ]),
                const SizedBox(height: AppSpacing.lg),
                const Text('المنتجات الأكثر مبيعًا', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: AppSpacing.sm),
                if (top.isEmpty)
                  SectionCard(title: 'لا توجد مبيعات', children: const [SizedBox(height: 40)])
                else
                  ...top.map((p) => Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          boxShadow: softShadow(),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: AppColors.seed.withOpacity(0.12), child: const Icon(Icons.local_mall_rounded, color: AppColors.seed)),
                          title: Text(p['product_name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('الكمية: ${(p['qty'] as num).toStringAsFixed(0)}'),
                          trailing: Text('${(p['revenue'] as num).toStringAsFixed(2)} د.ل', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.seed)),
                        ),
                      )),
              ],
            ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return StatChip(label: label, value: value, icon: icon, color: color);
  }
}
