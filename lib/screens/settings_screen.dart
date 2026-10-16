import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _connected ? Icons.check_circle : Icons.print,
                        color: _connected ? Colors.green : Colors.brown,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _connected ? 'الطابعة متصلة' : 'الطابعة غير متصلة',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1) اقترن بالطابعة من إعدادات البلوتوث في أندرويد.\n'
                    '2) شغّل الطابعة.\n'
                    '3) اضغط تحديث ثم اتصل بالطابعة.\n'
                    '4) جرّب اختبار الطباعة.',
                  ),
                  const SizedBox(height: 12),
                  if (_message != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_message!),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تحديث'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _connected ? _testPrint : null,
                        icon: const Icon(Icons.print),
                        label: const Text('اختبار'),
                      ),
                      if (_connected)
                        OutlinedButton.icon(
                          onPressed: _disconnect,
                          icon: const Icon(Icons.link_off),
                          label: const Text('قطع الاتصال'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'الأجهزة المقترنة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_devices.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد أجهزة مقترنة. اقترن بالطابعة من إعدادات النظام.'),
              ),
            )
          else
            ..._devices.map(
              (d) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(d.name ?? 'طابعة'),
                  subtitle: Text(d.address ?? ''),
                  trailing: _connected
                      ? const Icon(Icons.check, color: Colors.green)
                      : TextButton(
                          onPressed: () => _connect(d),
                          child: const Text('اتصال'),
                        ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'ملاحظات مهمة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '- التطبيق يعمل بدون إنترنت.\n'
                    '- البيانات محفوظة محلياً على الجهاز.\n'
                    '- بعض الطابعات لا تدعم الطباعة العربية بشكل جيد. إذا ظهرت العربية غير صحيحة، جرّب طباعة بالفصحى اللاتينية أو طابعة تدعم Arabic code page.\n'
                    '- عمل نسخة احتياطية دورية أمر ضروري.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
