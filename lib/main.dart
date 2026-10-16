import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'db/database_helper.dart';
import 'screens/home_screen.dart';
import 'screens/pin_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.init();
  runApp(const SouqnaApp());
}

class SouqnaApp extends StatelessWidget {
  const SouqnaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سوقنا',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
      ),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppGate(),
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});
  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool? _needPin;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final need = await AuthService.needPin();
    if (!mounted) return;
    setState(() => _needPin = need);
  }

  @override
  Widget build(BuildContext context) {
    if (_needPin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_needPin == true) {
      return PinScreen(onUnlocked: () => setState(() => _needPin = false));
    }
    return const HomeScreen();
  }
}
