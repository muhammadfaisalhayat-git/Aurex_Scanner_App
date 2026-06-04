// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Aurex Scanner';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get scanProduct => 'SCAN PRODUCT';

  @override
  String get adminDashboard => 'ADMIN DASHBOARD';

  @override
  String get nearExpiryProducts => 'NEAR EXPIRY PRODUCTS';

  @override
  String get productList => 'PRODUCT LIST';

  @override
  String get totalItems => 'TOTAL ITEMS';

  @override
  String get expired => 'EXPIRED';

  @override
  String get nearExpiry => 'NEAR EXPIRY';

  @override
  String get manageProducts => 'MANAGE PRODUCTS';

  @override
  String get manageUsers => 'MANAGE USERS';

  @override
  String get productName => 'Product Name';

  @override
  String get productCode => 'Product Code';

  @override
  String get mfgDate => 'MFG Date';

  @override
  String get expDate => 'EXP Date';

  @override
  String get quantity => 'Quantity';

  @override
  String get size => 'Size/Weight';

  @override
  String get warehouse => 'Warehouse';

  @override
  String get saveToHistory => 'SAVE TO HISTORY';

  @override
  String get updateProduct => 'UPDATE PRODUCT';

  @override
  String get edit => 'EDIT';

  @override
  String get logout => 'Logout';

  @override
  String get backupToServer => 'Backup to Server';

  @override
  String get restoreFromCloud => 'Restore from Cloud';

  @override
  String get wipeData => 'Wipe Data from Server';
}
