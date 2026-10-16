import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../services/update_service.dart';
import 'debts_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'sale_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  int _lowStock = 0;
  double _debts = 0;
  int _overdue = 0;
  bool _warned = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final low = await DatabaseHelper.instance.countLowStock();
    final debts = await DatabaseHelper.instance.totalOutstanding();
    final overdue = await DatabaseHelper.instance.overdueCount();
    if (!mounted) return;
    setState(() {
      _lowStock = low;
      _debts = debts;
      _overdue = overdue;
      _loading = false;
    });
    UpdateService.maybePrompt(context);
    if (_overdue > 0 && !_warned) {
      _warned = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تنبيه: $_overdue زبون متأخر عن السداد'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سوقنا'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('لوحة التحكم',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Wrap(spacing: 12, runSpacing: 12, children: [
                            _statCard('مخزون منخفض', '$_lowStock',
                                Icons.warning_amber_rounded, Colors.orange),
                            _statCard('إجمالي الذمم',
                                '${_debts.toStringAsFixed(2)} د.ل',
                                Icons.account_balance_wallet, Colors.red),
                            _statCard('متأخرون', '$_overdue', Icons.alarm,
                                Colors.purple),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.12,
                      ),
                      delegate: SliverChildListDelegate([
                        _actionButton('بيع', Icons.point_of_sale,
                            const Color(0xFF0F766E),
                            () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const SaleScreen()))),
                        _actionButton('مخزون', Icons.inventory_2, Colors.blue,
                            () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const InventoryScreen()))),
                        _actionButton('ذمم', Icons.people, Colors.deepPurple,
                            () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const DebtsScreen()))),
                        _actionButton('تقارير', Icons.bar_chart, Colors.teal,
                            () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ReportsScreen()))),
                        _actionButton('طابعة', Icons.print, Colors.brown,
                            () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                        _actionButton('تحديث', Icons.refresh,
                            Colors.grey.shade700, _load),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _actionButton(String title, IconData icon, Color color,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [color.withOpacity(0.16), color.withOpacity(0.05)],
            ),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 44, color: color),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}
