import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
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
  bool _loading = false;
  String? _message;

  bool _pinEnabled = false;
  bool _pinSet = false;
  List<String> _backups = [];

  @override
  void initState() {
    super.initState();
    _refreshPrinter();
    _refreshAuth();
    _refreshBackups();
  }

  Future<void> _refreshAuth() async {
    final en = await AuthService.isPinEnabled();
    final st = await AuthService.isPinSet();
    if (!mounted) return;
    setState(() {
      _pinEnabled = en;
      _pinSet = st;
    });
  }

  void _refreshBackups() {
    setState(() => _backups = BackupService.listBackups());
  }

  Future<void> _refreshPrinter() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final devices = await PrintService.bondedDevices();
      final connected = await PrintService.isConnected();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _connected = connected;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'تعذر جلب الأجهزة: $e';
      });
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => _loading = true);
    final ok = await PrintService.connect(device);
    if (!mounted) return;
    setState(() {
      _connected = ok;
      _loading = false;
      _message = ok ? 'تم الاتصال بـ ${device.name ?? device.address}' : 'فشل الاتصال';
    });
  }

  Future<void> _testPrint() async {
    setState(() => _loading = true);
    final error = await PrintService.printTest();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = error ?? 'تم إرسال اختبار الطباعة';
    });
  }

  Future<void> _disconnect() async {
    await PrintService.disconnect();
    if (!mounted) return;
    setState(() => _connected = false);
  }

  // ---------- PIN ----------
  Future<void> _enablePin() async {
    final pin = await _askPin('تعيين رقم سري', true);
    if (pin == null) return;
    await AuthService.setPin(pin);
    await _refreshAuth();
    _snack('تم تفعيل الرقم السري');
  }

  Future<void> _changePin() async {
    final old = await _askPin('الرقم الحالي', false);
    if (old == null) return;
    if (!await AuthService.verifyPin(old)) {
      _snack('الرقم الحالي غير صحيح');
      return;
    }
    final neu = await _askPin('الرقم الجديد', true);
    if (neu == null) return;
    await AuthService.setPin(neu);
    _snack('تم تغيير الرقم السري');
  }

  Future<void> _disablePin() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تعطيل الرقم السري'),
        content: const Text('هل تريد إلغاء القفل؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تعطيل')),
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
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: c1,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الرقم السري')),
          if (confirm) ...[
            const SizedBox(height: 10),
            TextField(
                controller: c2,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'تأكيد الرقم')),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final a = c1.text.trim();
              if (a.isEmpty || a.length < 4) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(const SnackBar(content: Text('4 أرقام على الأقل')));
                return;
              }
              if (confirm && a != c2.text.trim()) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(const SnackBar(content: Text('الرقمان غير متطابقين')));
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

  // ---------- Backup ----------
  Future<void> _createBackup() async {
    final name = await BackupService.createBackup();
    _refreshBackups();
    _snack('تم إنشاء نسخة: $name');
  }

  Future<void> _restore(String name) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('استعادة نسخة'),
        content: Text('سيتم استبدال البيانات الحالية بالنسخة:\n$name\nهل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('استعادة')),
        ],
      ),
    );
    if (yes != true) return;
    await BackupService.restoreBackup(name);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
        (r) => false);
    _snack('تمت الاستعادة');
  }

  Future<void> _delete(String name) async {
    BackupService.deleteBackup(name);
    _refreshBackups();
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _printerCard(),
          const SizedBox(height: 14),
          _pinCard(),
          const SizedBox(height: 14),
          _backupCard(),
        ],
      ),
    );
  }

  Widget _printerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_connected ? Icons.check_circle : Icons.print,
                color: _connected ? Colors.green : Colors.brown),
            const SizedBox(width: 10),
            Text(_connected ? 'الطابعة متصلة' : 'الطابعة غير متصلة',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          const Text(
              '1) اقترن بالطابعة من بلوتوث أندرويد.\n2) شغّل الطابعة.\n3) تحديث ثم اتصال ثم اختبار.'),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_message!)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
                onPressed: _refreshPrinter,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث')),
            OutlinedButton.icon(
                onPressed: _connected ? _testPrint : null,
                icon: const Icon(Icons.print),
                label: const Text('اختبار')),
            if (_connected)
              OutlinedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('قطع')),
          ]),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_devices.isEmpty)
            const Text('لا أجهزة مقترنة.')
          else
            ..._devices.map((d) => ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(d.name ?? 'طابعة'),
                  subtitle: Text(d.address ?? ''),
                  trailing: _connected
                      ? const Icon(Icons.check, color: Colors.green)
                      : TextButton(onPressed: () => _connect(d), child: const Text('اتصال')),
                )),
        ]),
      ),
    );
  }

  Widget _pinCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lock, color: Colors.deepPurple),
            const SizedBox(width: 10),
            const Text('الرقم السري (PIN)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text(_pinEnabled && _pinSet
              ? 'القفل مفعّل'
              : 'القفل غير مفعّل'),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (!_pinEnabled || !_pinSet)
              FilledButton.icon(
                  onPressed: _enablePin,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('تفعيل'))
            else ...[
              OutlinedButton.icon(
                  onPressed: _changePin,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تغيير')),
              OutlinedButton.icon(
                  onPressed: _disablePin,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('تعطيل')),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _backupCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.backup, color: Colors.teal),
            const SizedBox(width: 10),
            const Text('النسخ الاحتياطي والاستعادة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          const Text('احفظ نسخة من بياناتك داخل الجهاز، واستعدها عند الحاجة.'),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: _createBackup,
              icon: const Icon(Icons.add),
              label: const Text('إنشاء نسخة الآن')),
          const SizedBox(height: 12),
          if (_backups.isEmpty)
            const Text('لا توجد نسخ بعد.')
          else
            ..._backups.map((b) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.description),
                  title: Text(b, style: const TextStyle(fontSize: 13)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(onPressed: () => _restore(b), child: const Text('استعادة')),
                    IconButton(
                        onPressed: () => BackupService.shareBackup(b),
                        icon: const Icon(Icons.share, color: Colors.blue)),
                    IconButton(
                        onPressed: () => _delete(b),
                        icon: const Icon(Icons.delete, color: Colors.red)),
                  ]),
                )),
        ]),
      ),
    );
  }
}
