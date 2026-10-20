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
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBio();
  }

  Future<void> _checkBio() async {
    final available = await AuthService.isBiometricAvailable();
    if (mounted) setState(() => _bioAvailable = available);
  }

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
          const SnackBar(content: Text('الرقم السري غير صحيح'), backgroundColor: Colors.red));
    }
  }

  Future<void> _useBiometric() async {
    if (!_bioAvailable || _checking) return;
    setState(() => _checking = true);
    final ok = await AuthService.authenticateWithBiometric();
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      widget.onUnlocked();
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 72, color: Color(0xFF0F766E)),
                const SizedBox(height: 24),
                Text('أدخل الرقم السري',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    8,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _entry.length ? const Color(0xFF0F766E) : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _keypad(),
                const SizedBox(height: 24),
                if (_bioAvailable) ...[
                  ElevatedButton.icon(
                    onPressed: _checking ? null : _useBiometric,
                    icon: const Icon(Icons.fingerprint_rounded, size: 28),
                    label: const Text('استخدم البصمة', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextButton(onPressed: _forgot, child: const Text('نسيت الرقم السري؟')),
              ],
            ),
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
          if (k.isEmpty) return const SizedBox(width: 88, height: 72);
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
        width: 88,
        height: 72,
        child: FilledButton.tonal(
          onPressed: _checking ? null : onTap,
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
