import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

class PinScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PinScreen({super.key, required this.onUnlocked});
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _entry = '';
  bool _checking = false;

  void _tap(String d) {
    if (_entry.length >= 8) return;
    setState(() => _entry += d);
  }

  void _backspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    if (_entry.isEmpty || _checking) return;
    setState(() => _checking = true);
    final ok = await AuthService.verifyPin(_entry);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _entry = '');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرقم السري غير صحيح')));
    }
  }

  Future<void> _forgot() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('نسيت الرقم؟'),
        content: const Text(
            'سيتم فتح التطبيق بدون رقم سري. هذه الميزة لمن يملك الجهاز فعلًا؛ '
            'لا تستخدمها إلا إذا كنت صاحب المحل.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('فتح')),
        ],
      ),
    );
    if (yes == true) {
      await AuthService.disablePin();
      if (mounted) widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سوقنا — قفل'), automaticallyImplyLeading: false),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              Text('أدخل الرقم السري',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  8,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _entry.length ? Colors.teal : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _keypad(),
              const SizedBox(height: 12),
              TextButton(onPressed: _forgot, child: const Text('نسيت الرقم السري؟')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: keys.map((row) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((k) {
          if (k.isEmpty) return const SizedBox(width: 80, height: 64);
          if (k == '⌫') {
            return _key(k, onTap: _backspace);
          }
          return _key(k, onTap: () => _tap(k));
        }).toList(),
      )).toList(),
    );
  }

  Widget _key(String label, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 80,
        height: 64,
        child: FilledButton.tonal(
          onPressed: _checking ? null : onTap,
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(fontSize: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
