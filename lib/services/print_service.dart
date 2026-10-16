import 'dart:convert';
import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class EscPos {
  static const int esc = 0x1B;
  static const int gs = 0x1D;

  static List<int> init() => [esc, 0x40];
  static List<int> align(int value) => [esc, 0x61, value];
  static List<int> bold(bool value) => [esc, 0x45, value ? 1 : 0];

  static List<int> size({bool doubleHeight = false, bool doubleWidth = false}) {
    final int n = ((doubleHeight ? 1 : 0) << 4) | (doubleWidth ? 1 : 0);
    return [gs, 0x21, n];
  }

  static List<int> text(String value) => utf8.encode(value);
  static List<int> newline() => [0x0A];
  static List<int> feed(int lines) => [esc, 0x64, lines];
  static List<int> cut() => [gs, 0x56, 0x00];

  static List<int> textLine(
    String value, {
    int align = 0,
    bool bold = false,
    bool doubleSize = false,
  }) {
    final List<int> bytes = <int>[];
    bytes.addAll(EscPos.align(align));
    bytes.addAll(EscPos.bold(bold));
    if (doubleSize) {
      bytes.addAll(EscPos.size(doubleHeight: true, doubleWidth: true));
    }
    bytes.addAll(EscPos.text(value));
    bytes.addAll(EscPos.newline());
    if (doubleSize) {
      bytes.addAll(EscPos.size());
    }
    bytes.addAll(EscPos.bold(false));
    bytes.addAll(EscPos.align(0));
    return bytes;
  }
}

class PrintService {
  static final BlueThermalPrinter _printer = BlueThermalPrinter.instance;

  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final bool scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final bool connectOk =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    return scanOk && connectOk;
  }

  static Future<List<BluetoothDevice>> bondedDevices() async {
    await requestPermissions();
    return _printer.getBondedDevices();
  }

  static Future<bool> connect(BluetoothDevice device) async {
    await requestPermissions();
    final bool? ok = await _printer.connect(device);
    return ok == true;
  }

  static Future<bool> isConnected() async {
    try {
      return (await _printer.isConnected) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disconnect() async {
    try {
      await _printer.disconnect();
    } catch (_) {}
  }

  static Future<String?> printTest() async {
    if (!await isConnected()) {
      return 'الطابعة غير متصلة. اقترن بها من الإعدادات أولًا.';
    }
    try {
      final List<int> bytes = <int>[];
      bytes.addAll(EscPos.init());
      bytes.addAll(
        EscPos.textLine('سوقنا', align: 1, bold: true, doubleSize: true),
      );
      bytes.addAll(EscPos.textLine('اختبار الطابعة', align: 1));
      bytes.addAll(EscPos.textLine('--------------------------'));
      bytes.addAll(EscPos.textLine(
        'التاريخ: ${DateFormat('yyyy/MM/dd HH:mm', 'en').format(DateTime.now())}',
      ));
      bytes.addAll(
        EscPos.textLine('إذا ظهرت هذه الرسالة فالطابعة تعمل.', align: 1),
      );
      bytes.addAll(EscPos.feed(3));
      bytes.addAll(EscPos.cut());
      await _printer.writeBytes(bytes);
      return null;
    } catch (e) {
      return 'خطأ في الطباعة: $e';
    }
  }

  static Future<String?> printInvoice({
    required String invoiceNo,
    required DateTime date,
    required String? customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paid,
    required double change,
    required double debt,
    required String paymentMethod,
  }) async {
    if (!await isConnected()) {
      return 'الطابعة غير متصلة. اذهب إلى الإعدادات واتصل بالطابعة.';
    }
    try {
      const int width = 32;
      final List<int> bytes = <int>[];
      bytes.addAll(EscPos.init());
      bytes.addAll(
        EscPos.textLine('سوقنا', align: 1, bold: true, doubleSize: true),
      );
      bytes.addAll(EscPos.textLine('نظام محلات بدون إنترنت', align: 1));
      bytes.addAll(EscPos.textLine('--------------------------'));
      bytes.addAll(EscPos.textLine('فاتورة: $invoiceNo'));
      bytes.addAll(EscPos.textLine(
        'التاريخ: ${DateFormat('yyyy/MM/dd HH:mm', 'en').format(date)}',
      ));
      if (customerName != null && customerName.isNotEmpty) {
        bytes.addAll(EscPos.textLine('الزبون: $customerName'));
      }
      bytes.addAll(EscPos.textLine('الدفع: $paymentMethod'));
      bytes.addAll(EscPos.textLine('--------------------------'));
      for (final Map<String, dynamic> item in items) {
        final String name = item['product_name'] as String? ?? '';
        final double qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
        final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final double lineTotal = (item['total'] as num?)?.toDouble() ?? 0.0;
        bytes.addAll(EscPos.textLine(name));
        bytes.addAll(EscPos.textLine(
          _row('${_n(qty)} × ${_m(price)}', _m(lineTotal), width),
        ));
      }
      bytes.addAll(EscPos.textLine('--------------------------'));
      bytes.addAll(EscPos.textLine(_row('الإجمالي', _m(subtotal), width)));
      if (discount > 0) {
        bytes.addAll(
          EscPos.textLine(_row('الخصم', '- ${_m(discount)}', width)),
        );
      }
      bytes.addAll(
        EscPos.textLine(_row('الصافي', _m(total), width), bold: true),
      );
      bytes.addAll(EscPos.textLine(_row('المدفوع', _m(paid), width)));
      if (change > 0) {
        bytes.addAll(EscPos.textLine(_row('الباقي', _m(change), width)));
      }
      if (debt > 0) {
        bytes.addAll(
          EscPos.textLine(_row('الدين', _m(debt), width), bold: true),
        );
      }
      bytes.addAll(EscPos.textLine('--------------------------'));
      bytes.addAll(EscPos.textLine('شكرًا لتعاملكم معنا', align: 1));
      bytes.addAll(EscPos.feed(3));
      bytes.addAll(EscPos.cut());
      await _printer.writeBytes(bytes);
      return null;
    } catch (e) {
      return 'خطأ في طباعة الفاتورة: $e';
    }
  }

  static String _m(double value) => value.toStringAsFixed(2);

  static String _n(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static String _trunc(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max - 1)}…';
  }

  static String _row(String left, String right, int width) {
    left = _trunc(left, width - right.length - 1);
    return left.padRight(width - right.length) + right;
  }
}
