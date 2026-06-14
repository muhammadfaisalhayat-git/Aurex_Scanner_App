import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Aurex Scanner'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @scanProduct.
  ///
  /// In en, this message translates to:
  /// **'SCAN PRODUCT'**
  String get scanProduct;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'ADMIN DASHBOARD'**
  String get adminDashboard;

  /// No description provided for @nearExpiryProducts.
  ///
  /// In en, this message translates to:
  /// **'NEAR EXPIRY PRODUCTS'**
  String get nearExpiryProducts;

  /// No description provided for @productList.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT LIST'**
  String get productList;

  /// No description provided for @totalItems.
  ///
  /// In en, this message translates to:
  /// **'TOTAL ITEMS'**
  String get totalItems;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get expired;

  /// No description provided for @nearExpiry.
  ///
  /// In en, this message translates to:
  /// **'NEAR EXPIRY'**
  String get nearExpiry;

  /// No description provided for @manageProducts.
  ///
  /// In en, this message translates to:
  /// **'MANAGE PRODUCTS'**
  String get manageProducts;

  /// No description provided for @manageUsers.
  ///
  /// In en, this message translates to:
  /// **'MANAGE USERS'**
  String get manageUsers;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get productName;

  /// No description provided for @productCode.
  ///
  /// In en, this message translates to:
  /// **'Product Code'**
  String get productCode;

  /// No description provided for @mfgDate.
  ///
  /// In en, this message translates to:
  /// **'MFG Date'**
  String get mfgDate;

  /// No description provided for @expDate.
  ///
  /// In en, this message translates to:
  /// **'EXP Date'**
  String get expDate;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size/Weight'**
  String get size;

  /// No description provided for @warehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get warehouse;

  /// No description provided for @saveToHistory.
  ///
  /// In en, this message translates to:
  /// **'SAVE TO HISTORY'**
  String get saveToHistory;

  /// No description provided for @updateProduct.
  ///
  /// In en, this message translates to:
  /// **'UPDATE PRODUCT'**
  String get updateProduct;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'EDIT'**
  String get edit;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @backupToServer.
  ///
  /// In en, this message translates to:
  /// **'Backup to Server'**
  String get backupToServer;

  /// No description provided for @restoreFromCloud.
  ///
  /// In en, this message translates to:
  /// **'Restore from Cloud'**
  String get restoreFromCloud;

  /// No description provided for @wipeData.
  ///
  /// In en, this message translates to:
  /// **'Wipe Data from Server'**
  String get wipeData;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Bin Awf Agricultural'**
  String get companyName;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search name, date, cat...'**
  String get searchHint;

  /// No description provided for @projectOf.
  ///
  /// In en, this message translates to:
  /// **'A Project of Aurex ERP'**
  String get projectOf;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @allWarehouses.
  ///
  /// In en, this message translates to:
  /// **'All Warehouses'**
  String get allWarehouses;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter:'**
  String get filter;

  /// No description provided for @filterBy.
  ///
  /// In en, this message translates to:
  /// **'Filter By:'**
  String get filterBy;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found.'**
  String get noProductsFound;

  /// No description provided for @noProductsMatch.
  ///
  /// In en, this message translates to:
  /// **'No products match your filters'**
  String get noProductsMatch;

  /// No description provided for @clearAllFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear All Filters'**
  String get clearAllFilters;

  /// No description provided for @expiredBy.
  ///
  /// In en, this message translates to:
  /// **'Expired by: {days} days'**
  String expiredBy(int days);

  /// No description provided for @remainingDays.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {days} days'**
  String remainingDays(int days);

  /// No description provided for @pleaseWaitProcessing.
  ///
  /// In en, this message translates to:
  /// **'Please wait the picture is processing...'**
  String get pleaseWaitProcessing;

  /// No description provided for @noImageAvailable.
  ///
  /// In en, this message translates to:
  /// **'No image available'**
  String get noImageAvailable;

  /// No description provided for @productDetails.
  ///
  /// In en, this message translates to:
  /// **'Product Details'**
  String get productDetails;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @versionEdition.
  ///
  /// In en, this message translates to:
  /// **'v1.0.0 - Bin Awf Edition'**
  String get versionEdition;

  /// No description provided for @configuration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @enableBiometric.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric Login'**
  String get enableBiometric;

  /// No description provided for @testScanBeep.
  ///
  /// In en, this message translates to:
  /// **'TEST SCAN BEEP SOUND'**
  String get testScanBeep;

  /// No description provided for @cleanCloudBackups.
  ///
  /// In en, this message translates to:
  /// **'CLEAN CLOUD BACKUPS'**
  String get cleanCloudBackups;

  /// No description provided for @backupToCloud.
  ///
  /// In en, this message translates to:
  /// **'BACKUP TO CLOUD (RTDB)'**
  String get backupToCloud;

  /// No description provided for @restoreFromCloudRTDB.
  ///
  /// In en, this message translates to:
  /// **'RESTORE FROM CLOUD (RTDB)'**
  String get restoreFromCloudRTDB;

  /// No description provided for @premiumInsights.
  ///
  /// In en, this message translates to:
  /// **'Premium Insights'**
  String get premiumInsights;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember Me'**
  String get rememberMe;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'REGISTER'**
  String get register;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE WITH GOOGLE'**
  String get continueWithGoogle;

  /// No description provided for @biometricLoginError.
  ///
  /// In en, this message translates to:
  /// **'Please log in with email first to enable biometrics.'**
  String get biometricLoginError;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Aurex Scanner'**
  String get tagline;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'SAVE CHANGES'**
  String get saveChanges;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdated;

  /// No description provided for @biometricSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint to log in next time'**
  String get biometricSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
