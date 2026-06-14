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

  @override
  String get companyName => 'Bin Awf Agricultural';

  @override
  String get searchHint => 'Search name, date, cat...';

  @override
  String get projectOf => 'A Project of Aurex ERP';

  @override
  String get home => 'Home';

  @override
  String get allCategories => 'All Categories';

  @override
  String get allWarehouses => 'All Warehouses';

  @override
  String get filter => 'Filter:';

  @override
  String get filterBy => 'Filter By:';

  @override
  String get noProductsFound => 'No products found.';

  @override
  String get noProductsMatch => 'No products match your filters';

  @override
  String get clearAllFilters => 'Clear All Filters';

  @override
  String expiredBy(int days) {
    return 'Expired by: $days days';
  }

  @override
  String remainingDays(int days) {
    return 'Remaining: $days days';
  }

  @override
  String get pleaseWaitProcessing => 'Please wait the picture is processing...';

  @override
  String get noImageAvailable => 'No image available';

  @override
  String get productDetails => 'Product Details';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get versionEdition => 'v1.0.0 - Bin Awf Edition';

  @override
  String get configuration => 'Configuration';

  @override
  String get theme => 'Theme';

  @override
  String get systemDefault => 'System Default';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get enableBiometric => 'Enable Biometric Login';

  @override
  String get testScanBeep => 'TEST SCAN BEEP SOUND';

  @override
  String get cleanCloudBackups => 'CLEAN CLOUD BACKUPS';

  @override
  String get backupToCloud => 'BACKUP TO CLOUD (RTDB)';

  @override
  String get restoreFromCloudRTDB => 'RESTORE FROM CLOUD (RTDB)';

  @override
  String get premiumInsights => 'Premium Insights';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get rememberMe => 'Remember Me';

  @override
  String get login => 'LOGIN';

  @override
  String get register => 'REGISTER';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get continueWithGoogle => 'CONTINUE WITH GOOGLE';

  @override
  String get biometricLoginError =>
      'Please log in with email first to enable biometrics.';

  @override
  String get tagline => 'Aurex Scanner';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get fullName => 'Full Name';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get saveChanges => 'SAVE CHANGES';

  @override
  String get profileUpdated => 'Profile updated successfully';

  @override
  String get biometricSubtitle => 'Use fingerprint to log in next time';
}
