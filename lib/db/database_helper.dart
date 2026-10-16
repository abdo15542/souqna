import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;
  String _path = '';

  DatabaseHelper._();

  String get dbPath => _path;

  Future<void> init() async {
    _db = await _open();
  }

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> reopen() async {
    _db = await _open();
  }

  Future<void> checkpoint() async {
    final d = await db;
    await d.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  Future<Database> _open() async {
    final databasesPath = await getDatabasesPath();
    _path = join(databasesPath, 'souqna.db');
    return openDatabase(
      _path,
      version: 2,
      onConfigure: (Database d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT,
        category TEXT,
        purchase_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        quantity REAL NOT NULL DEFAULT 0,
        low_stock REAL NOT NULL DEFAULT 5,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        paid REAL NOT NULL,
        change REAL NOT NULL DEFAULT 0,
        cost REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'نقدي',
        created_at TEXT NOT NULL,
        printed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE SET NULL
      )''');
    await db.execute('''
      CREATE TABLE sale_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        qty REAL NOT NULL,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
      )''');
    await db.execute('''
      CREATE TABLE ledger(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        sale_id INTEGER,
        amount REAL NOT NULL,
        kind TEXT NOT NULL,
        note TEXT,
        due_date TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )''');
    await db.execute('''
      CREATE TABLE app_settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings(
          key TEXT PRIMARY KEY,
          value TEXT
        )''');
      await _createIndexes(db);
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_active ON products(active)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created ON sales(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_customer ON ledger(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_due ON ledger(amount, due_date)');
  }

  // ================= Settings =================
  Future<String?> getSetting(String key) async {
    final d = await db;
    final r = await d.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final d = await db;
    await d.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ================= Products =================
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final d = await db;
    product['created_at'] ??= DateTime.now().toIso8601String();
    return d.insert('products', product);
  }

  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final d = await db;
    return d.update('products', product, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> softDeleteProduct(int id) async {
    final d = await db;
    await d.update('products', {'active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getProducts({String search = '', bool lowOnly = false}) async {
    final d = await db;
    final where = <String>['active = 1'];
    final args = <dynamic>[];
    if (search.trim().isNotEmpty) {
      where.add('(name LIKE ? OR barcode LIKE ? OR category LIKE ?)');
      final q = '%${search.trim()}%';
      args.addAll([q, q, q]);
    }
    if (lowOnly) where.add('quantity <= low_stock');
    return d.query('products', where: where.join(' AND '), whereArgs: args,
        orderBy: 'name COLLATE NOCASE');
  }

  Future<Map<String, dynamic>?> getProduct(int id) async {
    final d = await db;
    final r = await d.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<int> countLowStock() async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COUNT(*) AS c FROM products WHERE active = 1 AND quantity <= low_stock');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // ================= Customers (single query, no N+1) =================
  Future<List<Map<String, dynamic>>> getCustomers({String search = ''}) async {
    final d = await db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final where = <String>[];
    final args = <dynamic>[today];
    if (search.trim().isNotEmpty) {
      where.add('(c.name LIKE ? OR c.phone LIKE ?)');
      final q = '%${search.trim()}%';
      args.addAll([q, q]);
    }
    final w = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await d.rawQuery('''
      SELECT c.id, c.name, c.phone, c.address, c.notes, c.created_at,
        COALESCE(SUM(l.amount), 0) AS balance,
        SUM(CASE WHEN l.amount > 0 AND l.due_date IS NOT NULL AND l.due_date <= ?
            THEN 1 ELSE 0 END) AS overdue_count
      FROM customers c
      LEFT JOIN ledger l ON l.customer_id = c.id
      $w
      GROUP BY c.id
      ORDER BY c.name COLLATE NOCASE
    ''', args);
    final out = <Map<String, dynamic>>[];
    for (final c in rows) {
      final balance = (c['balance'] as num?)?.toDouble() ?? 0.0;
      final oc = (c['overdue_count'] as num?)?.toInt() ?? 0;
      c['balance'] = balance;
      c['overdue'] = balance > 0 && oc > 0;
      out.add(c);
    }
    return out;
  }

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final d = await db;
    customer['created_at'] ??= DateTime.now().toIso8601String();
    return d.insert('customers', customer);
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> customer) async {
    final d = await db;
    return d.update('customers', customer, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getCustomer(int id) async {
    final d = await db;
    final r = await d.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<double> totalOutstanding() async {
    final d = await db;
    final r = await d.rawQuery('''
      SELECT COALESCE(SUM(bal), 0) AS total FROM (
        SELECT SUM(amount) AS bal FROM ledger GROUP BY customer_id HAVING bal > 0
      )''');
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> overdueCount() async {
    final d = await db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final r = await d.rawQuery('''
      SELECT COUNT(DISTINCT l.customer_id) AS c
      FROM ledger l
      JOIN (SELECT customer_id, SUM(amount) AS bal FROM ledger GROUP BY customer_id HAVING bal > 0) t
        ON t.customer_id = l.customer_id
      WHERE l.amount > 0 AND l.due_date IS NOT NULL AND l.due_date <= ?
    ''', [today]);
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // ================= Ledger =================
  Future<int> addLedgerEntry({
    required int customerId,
    required double amount,
    required String kind,
    String? note,
    String? dueDate,
    int? saleId,
  }) async {
    final d = await db;
    return d.insert('ledger', {
      'customer_id': customerId,
      'sale_id': saleId,
      'amount': amount,
      'kind': kind,
      'note': note,
      'due_date': dueDate,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getLedger(int customerId) async {
    final d = await db;
    return d.query('ledger', where: 'customer_id = ?', whereArgs: [customerId],
        orderBy: 'created_at DESC');
  }

  // ================= Sales =================
  Future<String> _nextInvoiceNo(Transaction txn) async {
    final r = await txn.rawQuery('SELECT COUNT(*) AS c FROM sales');
    final count = Sqflite.firstIntValue(r) ?? 0;
    return 'INV-${(count + 1).toString().padLeft(5, '0')}';
  }

  Future<Map<String, dynamic>> saveSale({
    required List<CartItem> items,
    required double discount,
    required double paid,
    required String paymentMethod,
    int? customerId,
    String? debtDueDate,
  }) async {
    if (items.isEmpty) throw Exception('السلة فارغة');
    final d = await db;
    return d.transaction((txn) async {
      double subtotal = 0;
      double cost = 0;
      for (final item in items) {
        final pid = item.product['id'] as int;
        final rows = await txn.query('products',
            where: 'id = ? AND active = 1', whereArgs: [pid], limit: 1);
        if (rows.isEmpty) throw Exception('المنتج غير موجود: ${item.name}');
        final stock = (rows.first['quantity'] as num).toDouble();
        if (item.qty > stock) throw Exception('الكمية غير كافية لـ ${item.name}');
        subtotal += item.lineTotal;
        cost += item.lineCost;
      }
      double effectiveDiscount = discount < 0 ? 0.0 : discount;
      if (effectiveDiscount > subtotal) effectiveDiscount = subtotal;
      final double total = subtotal - effectiveDiscount;
      final double paidAmount = paid < 0 ? 0.0 : paid;
      final double change = paidAmount > total ? paidAmount - total : 0.0;
      final double debt = total > paidAmount ? total - paidAmount : 0.0;
      if (debt > 0.009 && customerId == null) {
        throw Exception('اختر زبونًا لتسجيل الدين');
      }
      final invoiceNo = await _nextInvoiceNo(txn);
      final now = DateTime.now().toIso8601String();
      final saleId = await txn.insert('sales', {
        'invoice_no': invoiceNo,
        'customer_id': customerId,
        'subtotal': subtotal,
        'discount': effectiveDiscount,
        'total': total,
        'paid': paidAmount,
        'change': change,
        'cost': cost,
        'payment_method': paymentMethod,
        'created_at': now,
        'printed': 0,
      });
      for (final item in items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.product['id'],
          'product_name': item.name,
          'qty': item.qty,
          'price': item.price,
          'cost': item.cost,
          'total': item.lineTotal,
        });
        await txn.rawUpdate('UPDATE products SET quantity = quantity - ? WHERE id = ?',
            [item.qty, item.product['id']]);
      }
      if (debt > 0.009) {
        await txn.insert('ledger', {
          'customer_id': customerId,
          'sale_id': saleId,
          'amount': debt,
          'kind': 'دين',
          'note': 'دين فاتورة $invoiceNo',
          'due_date': debtDueDate,
          'created_at': now,
        });
      }
      return {'id': saleId, 'invoice_no': invoiceNo};
    });
  }

  Future<void> markPrinted(int saleId) async {
    final d = await db;
    await d.update('sales', {'printed': 1}, where: 'id = ?', whereArgs: [saleId]);
  }

  // ================= Reports =================
  Future<Map<String, dynamic>> getReport(DateTime start, DateTime end) async {
    final d = await db;
    final s = DateTime(start.year, start.month, start.day).toIso8601String();
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999).toIso8601String();
    final totals = await d.rawQuery('''
      SELECT COUNT(*) AS invoices,
        COALESCE(SUM(total), 0) AS revenue,
        COALESCE(SUM(total - cost), 0) AS profit,
        COALESCE(SUM(paid), 0) AS paid,
        COALESCE(SUM(CASE WHEN total > paid THEN total - paid ELSE 0 END), 0) AS credit
      FROM sales WHERE created_at BETWEEN ? AND ?
    ''', [s, e]);
    final top = await d.rawQuery('''
      SELECT si.product_name, SUM(si.qty) AS qty, SUM(si.total) AS revenue
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at BETWEEN ? AND ?
      GROUP BY si.product_id, si.product_name
      ORDER BY qty DESC LIMIT 10
    ''', [s, e]);
    final t = totals.first;
    return {
      'invoices': Sqflite.firstIntValue(totals) ?? 0,
      'revenue': (t['revenue'] as num?)?.toDouble() ?? 0.0,
      'profit': (t['profit'] as num?)?.toDouble() ?? 0.0,
      'paid': (t['paid'] as num?)?.toDouble() ?? 0.0,
      'credit': (t['credit'] as num?)?.toDouble() ?? 0.0,
      'top': top,
    };
  }

  // ================= Returns (رجيع) =================
  Future<List<Map<String, dynamic>>> getRecentSales({int limit = 50}) async {
    final d = await db;
    return d.query('sales', orderBy: 'created_at DESC', limit: limit);
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final d = await db;
    return d.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  /// يعيد الكميات للمخزون ويُسجّل قيد ذمم عكسي (خصم من دين الزبون أو زيادة رصيده).
  Future<void> processReturn({
    required int saleId,
    required List<int> itemIds,
    required String reason,
  }) async {
    if (itemIds.isEmpty) throw Exception('اختر عنصرًا للرجيع');
    final d = await db;
    await d.transaction((txn) async {
      final saleRows = await txn.query('sales',
          where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (saleRows.isEmpty) throw Exception('الفاتورة غير موجودة');
      final sale = saleRows.first;
      double returnedValue = 0.0;
      for (final itemId in itemIds) {
        final rows = await txn.query('sale_items',
            where: 'id = ? AND sale_id = ?', whereArgs: [itemId, saleId], limit: 1);
        if (rows.isEmpty) continue;
        final it = rows.first;
        final qty = (it['qty'] as num?)?.toDouble() ?? 0.0;
        final total = (it['total'] as num?)?.toDouble() ?? 0.0;
        final pid = it['product_id'];
        returnedValue += total;
        if (pid != null) {
          await txn.rawUpdate(
              'UPDATE products SET quantity = quantity + ? WHERE id = ?', [qty, pid]);
        }
        await txn.delete('sale_items', where: 'id = ?', whereArgs: [itemId]);
      }
      // تسجيل القيد العكسي في دفتر الزبون إن وُجد زبون مرتبط
      final cid = sale['customer_id'];
      if (cid != null && returnedValue > 0.009) {
        await txn.insert('ledger', {
          'customer_id': cid,
          'sale_id': saleId,
          'amount': -returnedValue,
          'kind': 'رجيع',
          'note': 'رجيع فاتورة ${sale['invoice_no']} ($reason)',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      // تحديث إجمالي الفاتورة المطروح منها المرتجع
      final newTotal = ((sale['total'] as num?)?.toDouble() ?? 0.0) - returnedValue;
      await txn.update('sales', {'total': newTotal < 0 ? 0.0 : newTotal},
          where: 'id = ?', whereArgs: [saleId]);
    });
  }

}
