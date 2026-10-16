import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  DatabaseHelper._();

  Future<void> init() async {
    _db = await _open();
  }

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'souqna.db');

    return openDatabase(
      path,
      version: 1,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
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
      )
    ''');

    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

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
      )
    ''');

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
      )
    ''');

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
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_products_active ON products(active)',
    );
    await db.execute(
      'CREATE INDEX idx_sales_created ON sales(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_ledger_customer ON ledger(customer_id)',
    );
  }

  // ================= Products =================

  Future<int> insertProduct(Map<String, dynamic> product) async {
    final database = await db;
    product['created_at'] ??= DateTime.now().toIso8601String();
    return database.insert('products', product);
  }

  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final database = await db;
    return database.update(
      'products',
      product,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> softDeleteProduct(int id) async {
    final database = await db;
    await database.update(
      'products',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getProducts({
    String search = '',
    bool lowOnly = false,
  }) async {
    final database = await db;

    final where = <String>['active = 1'];
    final args = <dynamic>[];

    if (search.trim().isNotEmpty) {
      where.add('(name LIKE ? OR barcode LIKE ? OR category LIKE ?)');
      final q = '%${search.trim()}%';
      args.addAll([q, q, q]);
    }

    if (lowOnly) {
      where.add('quantity <= low_stock');
    }

    return database.query(
      'products',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE',
    );
  }

  Future<Map<String, dynamic>?> getProduct(int id) async {
    final database = await db;
    final rows = await database.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> countLowStock() async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT COUNT(*) AS c
      FROM products
      WHERE active = 1 AND quantity <= low_stock
    ''');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // ================= Customers =================

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final database = await db;
    customer['created_at'] ??= DateTime.now().toIso8601String();
    return database.insert('customers', customer);
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> customer) async {
    final database = await db;
    return database.update(
      'customers',
      customer,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getCustomer(int id) async {
    final database = await db;
    final rows = await database.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getCustomers({
    String search = '',
  }) async {
    final database = await db;

    final where = <String>[];
    final args = <dynamic>[];

    if (search.trim().isNotEmpty) {
      where.add('(name LIKE ? OR phone LIKE ?)');
      final q = '%${search.trim()}%';
      args.addAll([q, q]);
    }

    final customers = await database.query(
      'customers',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name COLLATE NOCASE',
    );

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = <Map<String, dynamic>>[];

    for (final customer in customers) {
      final rows = await database.rawQuery('''
        SELECT
          COALESCE(SUM(amount), 0) AS balance,
          SUM(
            CASE
              WHEN amount > 0
               AND due_date IS NOT NULL
               AND due_date <= ?
              THEN 1 ELSE 0
            END
          ) AS overdue_count
        FROM ledger
        WHERE customer_id = ?
      ''', [today, customer['id']]);

      final balance =
          (rows.first['balance'] as num?)?.toDouble() ?? 0;
      final overdueCount =
          (rows.first['overdue_count'] as num?)?.toInt() ?? 0;

      customer['balance'] = balance;
      customer['overdue'] = balance > 0 && overdueCount > 0;
      result.add(customer);
    }

    return result;
  }

  Future<double> totalOutstanding() async {
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT COALESCE(SUM(balance), 0) AS total
      FROM (
        SELECT SUM(amount) AS balance
        FROM ledger
        GROUP BY customer_id
        HAVING balance > 0
      )
    ''');
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> overdueCount() async {
    final database = await db;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final rows = await database.rawQuery('''
      SELECT COUNT(DISTINCT l.customer_id) AS c
      FROM ledger l
      JOIN (
        SELECT customer_id, SUM(amount) AS bal
        FROM ledger
        GROUP BY customer_id
        HAVING bal > 0
      ) t ON t.customer_id = l.customer_id
      WHERE l.amount > 0
        AND l.due_date IS NOT NULL
        AND l.due_date <= ?
    ''', [today]);

    return Sqflite.firstIntValue(rows) ?? 0;
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
    final database = await db;
    return database.insert('ledger', {
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
    final database = await db;
    return database.query(
      'ledger',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
  }

  // ================= Sales =================

  Future<String> _nextInvoiceNo(Transaction txn) async {
    final rows = await txn.rawQuery('SELECT COUNT(*) AS c FROM sales');
    final count = Sqflite.firstIntValue(rows) ?? 0;
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
    if (items.isEmpty) {
      throw Exception('السلة فارغة');
    }

    final database = await db;

    return database.transaction((txn) async {
      double subtotal = 0;
      double cost = 0;

      for (final item in items) {
        final productId = item.product['id'] as int;
        final rows = await txn.query(
          'products',
          where: 'id = ? AND active = 1',
          whereArgs: [productId],
          limit: 1,
        );

        if (rows.isEmpty) {
          throw Exception('المنتج غير موجود: ${item.name}');
        }

        final stock = (rows.first['quantity'] as num).toDouble();
        if (item.qty > stock) {
          throw Exception('الكمية غير كافية لـ ${item.name}');
        }

        subtotal += item.lineTotal;
        cost += item.lineCost;
      }

      double effectiveDiscount = discount < 0 ? 0.0 : discount;
      if (effectiveDiscount > subtotal) {
        effectiveDiscount = subtotal;
      }

      final double total = subtotal - effectiveDiscount;
      final double paidAmount = paid < 0 ? 0.0 : paid;
      final double change = paidAmount > total ? paidAmount - total : 0.0;
      final double debt = total > paidAmount ? total - paidAmount : 0.0;

      if (debt > 0.009 && customerId == null) {
        throw Exception('اختر زبوناً لتسجيل الدين');
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

        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [item.qty, item.product['id']],
        );
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

      return {
        'id': saleId,
        'invoice_no': invoiceNo,
      };
    });
  }

  Future<void> markPrinted(int saleId) async {
    final database = await db;
    await database.update(
      'sales',
      {'printed': 1},
      where: 'id = ?',
      whereArgs: [saleId],
    );
  }

  // ================= Reports =================

  Future<Map<String, dynamic>> getReport(
    DateTime start,
    DateTime end,
  ) async {
    final database = await db;

    final s = DateTime(start.year, start.month, start.day)
        .toIso8601String();
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999)
        .toIso8601String();

    final totals = await database.rawQuery('''
      SELECT
        COUNT(*) AS invoices,
        COALESCE(SUM(total), 0) AS revenue,
        COALESCE(SUM(total - cost), 0) AS profit,
        COALESCE(SUM(paid), 0) AS paid,
        COALESCE(SUM(CASE WHEN total > paid THEN total - paid ELSE 0 END), 0) AS credit
      FROM sales
      WHERE created_at BETWEEN ? AND ?
    ''', [s, e]);

    final top = await database.rawQuery('''
      SELECT
        si.product_name,
        SUM(si.qty) AS qty,
        SUM(si.total) AS revenue
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at BETWEEN ? AND ?
      GROUP BY si.product_id, si.product_name
      ORDER BY qty DESC
      LIMIT 10
    ''', [s, e]);

    final t = totals.first;

    return {
      'invoices': Sqflite.firstIntValue(totals) ?? 0,
      'revenue': (t['revenue'] as num?)?.toDouble() ?? 0,
      'profit': (t['profit'] as num?)?.toDouble() ?? 0,
      'paid': (t['paid'] as num?)?.toDouble() ?? 0,
      'credit': (t['credit'] as num?)?.toDouble() ?? 0,
      'top': top,
    };
  }
}
