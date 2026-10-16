import 'package:flutter/material.dart';

import '../db/database_helper.dart';
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

    if (_overdue > 0 && !_warned) {
      _warned = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تنبيه: $_overdue زبون متأخر عن السداد'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سوقنا'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات والطابعة',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'لوحة التحكم',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statCard(
                        title: 'مخزون منخفض',
                        value: '$_lowStock',
                        icon: Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      _statCard(
                        title: 'إجمالي الذمم',
                        value: '${_debts.toStringAsFixed(2)} د.ل',
                        icon: Icons.account_balance_wallet,
                        color: Colors.red,
                      ),
                      _statCard(
                        title: 'متأخرون',
                        value: '$_overdue',
                        icon: Icons.alarm,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.12,
                    children: [
                      _actionButton(
                        title: 'بيع',
                        icon: Icons.point_of_sale,
                        color: const Color(0xFF0F766E),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SaleScreen()),
                          );
                        },
                      ),
                      _actionButton(
                        title: 'مخزون',
                        icon: Icons.inventory_2,
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const InventoryScreen()),
                          );
                        },
                      ),
                      _actionButton(
                        title: 'ذمم',
                        icon: Icons.people,
                        color: Colors.deepPurple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DebtsScreen()),
                          );
                        },
                      ),
                      _actionButton(
                        title: 'تقارير',
                        icon: Icons.bar_chart,
                        color: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ReportsScreen()),
                          );
                        },
                      ),
                      _actionButton(
                        title: 'طابعة',
                        icon: Icons.print,
                        color: Colors.brown,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                      _actionButton(
                        title: 'تحديث',
                        icon: Icons.refresh,
                        color: Colors.grey.shade700,
                        onTap: _load,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                color.withOpacity(0.16),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 44, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
