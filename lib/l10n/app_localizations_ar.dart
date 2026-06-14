// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'أوريكس سكانر';

  @override
  String get dashboard => 'لوحة القيادة';

  @override
  String get scanProduct => 'مسح المنتج';

  @override
  String get adminDashboard => 'لوحة تحكم المسؤول';

  @override
  String get nearExpiryProducts => 'منتجات قريبة الانتهاء';

  @override
  String get productList => 'قائمة المنتجات';

  @override
  String get totalItems => 'إجمالي العناصر';

  @override
  String get expired => 'منتهي الصلاحية';

  @override
  String get nearExpiry => 'قريب الانتهاء';

  @override
  String get manageProducts => 'إدارة المنتجات';

  @override
  String get manageUsers => 'إدارة المستخدمين';

  @override
  String get productName => 'اسم المنتج';

  @override
  String get productCode => 'رمز المنتج';

  @override
  String get mfgDate => 'تاريخ الإنتاج';

  @override
  String get expDate => 'تاريخ الانتهاء';

  @override
  String get quantity => 'الكمية';

  @override
  String get size => 'الحجم / الوزن';

  @override
  String get warehouse => 'المستودع';

  @override
  String get saveToHistory => 'حفظ في السجل';

  @override
  String get updateProduct => 'تحديث المنتج';

  @override
  String get edit => 'تعديل';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get backupToServer => 'نسخ احتياطي للخادم';

  @override
  String get restoreFromCloud => 'استعادة من السحابة';

  @override
  String get wipeData => 'مسح البيانات من الخادم';

  @override
  String get companyName => 'بن عوف الزراعية';

  @override
  String get searchHint => 'بحث بالاسم، التاريخ، الفئة...';

  @override
  String get projectOf => 'مشروع من أوريكس إي آر بي';

  @override
  String get home => 'الرئيسية';

  @override
  String get allCategories => 'جميع الفئات';

  @override
  String get allWarehouses => 'جميع المستودعات';

  @override
  String get filter => 'تصفية:';

  @override
  String get filterBy => 'تصفية حسب:';

  @override
  String get noProductsFound => 'لم يتم العثور على منتجات.';

  @override
  String get noProductsMatch => 'لا توجد منتجات تطابق عوامل التصفية الخاصة بك';

  @override
  String get clearAllFilters => 'مسح جميع عوامل التصفية';

  @override
  String expiredBy(int days) {
    return 'منتهي منذ: $days أيام';
  }

  @override
  String remainingDays(int days) {
    return 'متبقي: $days أيام';
  }

  @override
  String get pleaseWaitProcessing => 'يرجى الانتظار، الصورة قيد المعالجة...';

  @override
  String get noImageAvailable => 'لا توجد صورة متاحة';

  @override
  String get productDetails => 'تفاصيل المنتج';

  @override
  String get settings => 'الإعدادات';

  @override
  String get account => 'الحساب';

  @override
  String get versionEdition => 'v1.0.0 - إصدار بن عوف';

  @override
  String get configuration => 'التكوين';

  @override
  String get theme => 'المظهر';

  @override
  String get systemDefault => 'تلقائي النظام';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'داكن';

  @override
  String get enableBiometric => 'تفعيل تسجيل الدخول البيومتري';

  @override
  String get testScanBeep => 'اختبار صوت المسح';

  @override
  String get cleanCloudBackups => 'مسح النسخ الاحتياطية السحابية';

  @override
  String get backupToCloud => 'نسخ احتياطي للسحابة (RTDB)';

  @override
  String get restoreFromCloudRTDB => 'استعادة من السحابة (RTDB)';

  @override
  String get premiumInsights => 'رؤى متميزة';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get rememberMe => 'تذكرني';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get continueWithGoogle => 'المتابعة باستخدام جوجل';

  @override
  String get biometricLoginError =>
      'يرجى تسجيل الدخول بالبريد الإلكتروني أولاً لتمكين القياسات الحيوية.';

  @override
  String get tagline => 'أوريكس سكانر';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get emailAddress => 'البريد الإلكتروني';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String get biometricSubtitle =>
      'استخدم بصمة الإصبع لتسجيل الدخول في المرة القادمة';
}
