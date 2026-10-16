import 'package:flutter/material.dart';

import '../db/database_helper.dart';

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
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)));
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
        title: const Text('تصدير CSV (انسخ النص)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: SelectableText(_csv(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
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
          IconButton(onPressed: _showCsv, icon: const Icon(Icons.table_view), tooltip: 'تصدير CSV'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
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
                const SizedBox(height: 14),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _card('المبيعات', '${revenue.toStringAsFixed(2)} د.ل', Icons.attach_money, Colors.teal),
                  _card('الأرباح', '${profit.toStringAsFixed(2)} د.ل', Icons.trending_up, Colors.green),
                  _card('الفواتير', '$invoices', Icons.receipt_long, Colors.blue),
                  _card('الآجل في الفترة', '${credit.toStringAsFixed(2)} د.ل', Icons.credit_score, Colors.red),
                ]),
                const SizedBox(height: 18),
                const Text('المنتجات الأكثر مبيعًا',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (top.isEmpty)
                  const Card(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('لا توجد مبيعات في هذه الفترة'))))
                else
                  ...top.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.local_mall),
                          title: Text(p['product_name'] as String),
                          subtitle: Text('الكمية: ${(p['qty'] as num).toStringAsFixed(0)}'),
                          trailing: Text('${(p['revenue'] as num).toStringAsFixed(2)} د.ل',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )),
              ],
            ),
    );
  }

  Widget _card(String title, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}
