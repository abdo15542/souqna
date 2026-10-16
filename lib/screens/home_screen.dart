import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../db/database_helper.dart';
import '../services/update_service.dart';
import 'debts_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'returns_screen.dart';
import 'sale_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  bool _loading = true;
  int _lowStock = 0;
  double _debts = 0;
  int _overdue = 0;
  bool _warned = false;

  @override
  void initState() {
    super.initState();
    _load();
    UpdateService.check().then((info) {
      if (info != null && mounted) _showUpdateDialog(info);
    });
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تنبيه: $_overdue زبون متأخر عن السداد'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Row(children: [
          const Icon(Icons.system_update_alt_rounded, color: AppColors.seed),
          const SizedBox(width: AppSpacing.sm),
          const Text('نسخة جديدة متوفرة'),
        ]),
        content: Text('صدرت النسخة ${info.latestVersion} (لديك $APP_VERSION).\n'
            'سيتم تنزيلها وفتح شاشة التنصيب. بياناتك ستبقى محفوظة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لاحقًا')),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await UpdateService.install(info.apkUrl);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(err == null ? 'جارٍ فتح شاشة التنصيب…' : 'خطأ: $err'),
              ));
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('تحديث الآن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _tabIndex,
      children: [
        _dashboard(),
        const SaleScreen(),
        const InventoryScreen(),
        const DebtsScreen(),
        const SettingsScreen(),
      ],
    );
  }

  Widget _dashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سوقنا'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _tabIndex = 4),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'الإعدادات',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== شريط الإحصائيات =====
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                      child: Text('نظرة عامة', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade700)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        children: [
                          StatChip(label: 'مخزون منخفض', value: '$_lowStock', icon: Icons.warning_amber_rounded, color: AppColors.warning),
                          const SizedBox(width: AppSpacing.sm),
                          StatChip(label: 'إجمالي الذمم', value: '${_debts.toStringAsFixed(2)} د.ل', icon: Icons.account_balance_wallet_rounded, color: AppColors.danger),
                          const SizedBox(width: AppSpacing.sm),
                          StatChip(label: 'متأخرون', value: '$_overdue', icon: Icons.alarm_rounded, color: AppColors.purple),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ===== قسم الإجراءات (بعنوان واضح ومسافة كافية) =====
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Row(children: [
                        Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.seed, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: AppSpacing.sm),
                        Text('الإجراءات السريعة', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 20)),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 1.15,
                        children: [
                          ActionCard(title: 'بيع جديد', subtitle: 'أنجز فاتورة بسرعة', icon: Icons.point_of_sale_rounded, color: AppColors.seed, onTap: () => setState(() => _tabIndex = 1)),
                          ActionCard(title: 'المخزون', subtitle: 'منتجات وأسعار وكميات', icon: Icons.inventory_2_rounded, color: AppColors.info, onTap: () => setState(() => _tabIndex = 2)),
                          ActionCard(title: 'الذمم', subtitle: 'زبائن وديون ودفعات', icon: Icons.groups_rounded, color: AppColors.purple, onTap: () => setState(() => _tabIndex = 3)),
                          ActionCard(title: 'التقارير', subtitle: 'مبيعات وأرباح وأكثر مبيعًا', icon: Icons.insights_rounded, color: AppColors.success, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
                          ActionCard(title: 'الرجيع', subtitle: 'إرجاع عناصر للفواتير', icon: Icons.assignment_return_rounded, color: AppColors.danger, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnsScreen()))),
                          ActionCard(title: 'الطابعة', subtitle: 'اقتران واختبار ESC/POS', icon: Icons.print_rounded, color: AppColors.brown, onTap: () => setState(() => _tabIndex = 4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('تحديث البيانات'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_rounded), label: 'بيع'),
          NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'مخزون'),
          NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'ذمم'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'إعدادات'),
        ],
      ),
    );
  }
}
