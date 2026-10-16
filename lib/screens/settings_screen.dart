import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/print_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<BluetoothDevice> _devices = [];
  bool _connected = false;
  bool _loadingPrinter = false;
  String? _printerMsg;

  bool _pinEnabled = false;
  bool _pinSet = false;
  List<String> _backups = [];
  bool _busyBackup = false;

  @override
  void initState() {
    super.initState();
    _refreshPrinter();
    _refreshAuth();
    _refreshBackups();
  }

  // ================= Printer =================
  Future<void> _refreshPrinter() async {
    setState(() {
      _loadingPrinter = true;
      _printerMsg = null;
    });
    try {
      final devices = await PrintService.bondedDevices();
      final connected = await PrintService.isConnected();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _connected = connected;
        _loadingPrinter = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPrinter = false;
        _printerMsg = 'تعذر جلب الأجهزة: $e';
      });
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => _loadingPrinter = true);
    final ok = await PrintService.connect(device);
    if (!mounted) return;
    setState(() {
      _connected = ok;
      _loadingPrinter = false;
      _printerMsg = ok ? 'تم الاتصال بـ ${device.name ?? device.address}' : 'فشل الاتصال';
    });
  }

  Future<void> _testPrint() async {
    setState(() => _loadingPrinter = true);
    final error = await PrintService.printTest();
    if (!mounted) return;
    setState(() {
      _loadingPrinter = false;
      _printerMsg = error ?? '✓ تم إرسال اختبار الطباعة بنجاح';
    });
  }

  Future<void> _disconnect() async {
    await PrintService.disconnect();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _printerMsg = 'تم قطع الاتصال';
    });
  }

  // ================= Auth / PIN =================
  Future<void> _refreshAuth() async {
    final en = await AuthService.isPinEnabled();
    final st = await AuthService.isPinSet();
    if (!mounted) return;
    setState(() {
      _pinEnabled = en;
      _pinSet = st;
    });
  }

  Future<void> _enablePin() async {
    final pin = await _askPin('تعيين رقم سري', true);
    if (pin == null) return;
    await AuthService.setPin(pin);
    await _refreshAuth();
    _snack('✓ تم تفعيل الرقم السري');
  }

  Future<void> _changePin() async {
    final old = await _askPin('الرقم الحالي', false);
    if (old == null) return;
    if (!await AuthService.verifyPin(old)) {
      _snack('✗ الرقم الحالي غير صحيح');
      return;
    }
    final neu = await _askPin('الرقم الجديد', true);
    if (neu == null) return;
    await AuthService.setPin(neu);
    _snack('✓ تم تغيير الرقم السري');
  }

  Future<void> _disablePin() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('تعطيل الرقم السري'),
        content: const Text('هل تريد إلغاء القفل؟ لن يُطلب الرقم عند فتح التطبيق.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تعطيل'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await AuthService.disablePin();
      await _refreshAuth();
      _snack('تم تعطيل الرقم السري');
    }
  }

  Future<String?> _askPin(String title, bool confirm) async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c1, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرقم السري')),
          if (confirm) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: c2, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تأكيد الرقم')),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final a = c1.text.trim();
              if (a.isEmpty || a.length < 4) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('4 أرقام على الأقل')));
                return;
              }
              if (confirm && a != c2.text.trim()) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الرقمان غير متطابقين')));
                return;
              }
              Navigator.pop(ctx, a);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    return res;
  }

  // ================= Backup =================
  void _refreshBackups() {
    setState(() => _backups = BackupService.listBackups());
  }

  Future<void> _createBackup() async {
    setState(() => _busyBackup = true);
    try {
      final name = await BackupService.createBackup();
      _refreshBackups();
      _snack('✓ تم إنشاء نسخة: $name');
    } catch (e) {
      _snack('✗ فشل الإنشاء: $e');
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<void> _restore(String name) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('استعادة نسخة'),
        content: Text('سيتم استبدال البيانات الحالية بالنسخة:\n$name\n\nهل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.warning), onPressed: () => Navigator.pop(c, true), child: const Text('استعادة')),
        ],
      ),
    );
    if (yes != true) return;
    setState(() => _busyBackup = true);
    try {
      await BackupService.restoreBackup(name);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SettingsScreen()), (r) => false);
      _snack('✓ تمت الاستعادة');
    } catch (e) {
      _snack('✗ فشلت الاستعادة: $e');
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<void> _share(String name) async {
    try {
      await BackupService.shareBackup(name);
    } catch (e) {
      _snack('✗ تعذرت المشاركة: $e');
    }
  }

  Future<void> _delete(String name) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('حذف نسخة'),
        content: Text('سيتم حذف $name نهائيًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (yes == true) {
      BackupService.deleteBackup(name);
      _refreshBackups();
    }
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _printerSection(),
          const SizedBox(height: AppSpacing.md),
          _pinSection(),
          const SizedBox(height: AppSpacing.md),
          _backupSection(),
        ],
      ),
    );
  }

  Widget _printerSection() {
    return SectionCard(
      title: 'الطابعة الحرارية',
      accent: AppColors.brown,
      children: [
        // حالة الاتصال الكبيرة الواضحة
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _connected ? AppColors.success.withOpacity(0.10) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: _connected ? AppColors.success.withOpacity(0.3) : Colors.transparent),
          ),
          child: Row(children: [
            Icon(_connected ? Icons.check_circle_rounded : Icons.portable_wifi_off_rounded,
                color: _connected ? AppColors.success : Colors.grey.shade600, size: 28),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_connected ? 'متصلة' : 'غير متصلة', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: _connected ? AppColors.success : Colors.grey.shade700)),
              Text(_printerMsg ?? (_connected ? 'جاهزة للطباعة' : 'لم يتم اختيار طابعة بعد'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            ])),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        // تعليمات مختصرة ظاهرة دائمًا
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(color: AppColors.info.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.chip)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('1) اقترن بالطابعة من بلوتوث أندرويد.\n2) شغّل الطابعة.\n3) اضغط تحديث ثم اتصال ثم اختبار.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5))),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          FilledButton.icon(
            onPressed: _loadingPrinter ? null : _refreshPrinter,
            icon: _loadingPrinter ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh_rounded),
            label: const Text('تحديث القائمة'),
          ),
          OutlinedButton.icon(
            onPressed: (_connected && !_loadingPrinter) ? _testPrint : null,
            icon: const Icon(Icons.print_rounded),
            label: const Text('طباعة اختبار'),
          ),
          if (_connected)
            OutlinedButton.icon(
              onPressed: _loadingPrinter ? null : _disconnect,
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('قطع الاتصال'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger.withOpacity(0.4))),
            ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        // قائمة الأجهزة المقترنة
        if (_loadingPrinter && _devices.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: CircularProgressIndicator()))
        else if (_devices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('لا توجد أجهزة مقترنة. اذهب لإعدادات البلوتوث في الهاتف واقترن أولًا.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
          )
        else
          ..._devices.map((d) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: AppColors.brown.withOpacity(0.12), child: const Icon(Icons.bluetooth_rounded, color: AppColors.brown, size: 20)),
                title: Text(d.name ?? 'طابعة', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(d.address ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                trailing: _connected
                    ? const Icon(Icons.check_rounded, color: AppColors.success)
                    : TextButton(onPressed: () => _connect(d), child: const Text('اتصال')),
              )),
      ],
    );
  }

  Widget _pinSection() {
    final active = _pinEnabled && _pinSet;
    return SectionCard(
      title: 'الأمان — الرقم السري (PIN)',
      accent: AppColors.purple,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: active ? AppColors.success.withOpacity(0.10) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: active ? AppColors.success.withOpacity(0.3) : Colors.transparent),
          ),
          child: Row(children: [
            Icon(active ? Icons.lock_rounded : Icons.lock_open_rounded, color: active ? AppColors.success : Colors.grey.shade600, size: 28),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(active ? 'القفل مفعّل' : 'القفل غير مفعّل', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: active ? AppColors.success : Colors.grey.shade700)),
              Text(active ? 'سيُطلب الرقم عند فتح التطبيق أو العودة إليه' : 'التطبيق مفتوح لكل من يحمل الجهاز',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            ])),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          if (!active)
            FilledButton.icon(
              onPressed: _enablePin,
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('تفعيل الرقم السري'),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _changePin,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('تغيير الرقم'),
            ),
            OutlinedButton.icon(
              onPressed: _disablePin,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('تعطيل'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger.withOpacity(0.4))),
            ),
          ],
        ]),
      ],
    );
  }

  Widget _backupSection() {
    return SectionCard(
      title: 'النسخ الاحتياطي والاستعادة',
      accent: AppColors.seed,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.seed.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.input)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.cloud_upload_rounded, color: AppColors.seed, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('احفظ نسخة من قاعدة بياناتك داخل الجهاز، واستعدها عند الحاجة، أو شاركها خارجيًا عبر واتساب/جيميل/بلوتوث.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5))),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _busyBackup ? null : _createBackup,
          icon: _busyBackup ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_rounded),
          label: const Text('إنشاء نسخة احتياطية الآن'),
          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_backups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('لا توجد نسخ محفوظة بعد.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
          )
        else
          ..._backups.map((b) => Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm + 2),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(AppRadius.input), border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  const Icon(Icons.description_rounded, color: AppColors.slate, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(b, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  IconButton(isTooltipVisible: false, tooltip: 'مشاركة', onPressed: _busyBackup ? null : () => _share(b), icon: const Icon(Icons.share_rounded, color: AppColors.info, size: 20)),
                  IconButton(tooltip: 'استعادة', onPressed: _busyBackup ? null : () => _restore(b), icon: const Icon(Icons.restart_alt_rounded, color: AppColors.warning, size: 20)),
                  IconButton(tooltip: 'حذف', onPressed: _busyBackup ? null : () => _delete(b), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20)),
                ]),
              )),
      ],
    );
  }
}
