import 'package:flutter/widgets.dart';

/// All app text in one place, in both languages.
///
/// Usage:  final s = S.of(context);  Text(s.welcomeTitle)
///
/// The screens are written ONCE. Flutter flips the whole layout to
/// right-to-left automatically when the language is Arabic, so there is
/// no separate "Arabic screen".
class AppStrings {
  AppStrings._();

  static const Map<String, String> en = {
    'languageSwitch': 'عربي',
    'welcomeTitle': 'Welcome to Ethmar!',
    'welcomeBody': 'Grow your own little farm, one seed at a time.',
    'createAccount': 'Sign up',
    'haveAccount': 'Log in',
    'signUpTitle': 'Create your\naccount',
    'signUpAccent': 'your farm is waiting',
    'fullName': 'Full name',
    'fullNameHint': 'Noora',
    'email': 'Email',
    'emailHint': 'name@example.com',
    'password': 'Password',
    'passwordHint': 'At least 8 characters',
    'createButton': 'Create account',
    'alreadyHaveAccount': 'Already have an account?',
    'logInLink': 'Log in',
    'loginTitle': 'Welcome\nback!',
    'loginAccent': 'your plants missed you',
    'forgotPassword': 'Forgot password?',
    'loginButton': 'Log in',
    'newHere': 'New to Ethmar?',
    'createAccountLink': 'Create an account',
    'errNameRequired': 'Tell us your name so we can say hi',
    'errEmailRequired': 'Enter your email',
    'errEmailInvalid': "That email doesn't look right",
    'errPasswordRequired': 'Enter your password',
    'errPasswordShort': 'Use at least 8 characters',
    'showPassword': 'Show password',
    'hidePassword': 'Hide password',
    'back': 'Back',
    'accountCreated': 'Account created. Welcome to Ethmar!',
    'resetSoon': "Password reset is coming soon",
    'homeHello': 'Hello',
    'homeFriend': 'friend',
    'homeTitle': 'Your garden is\nalmost ready',
    'homeBody': "We're planting the next screens. Come back soon!",
    'logOut': 'Log out',
  };

  static const Map<String, String> ar = {
    'languageSwitch': 'English',
    'welcomeTitle': 'أهلًا بك في إثمار!',
    'welcomeBody': 'ازرع مزرعتك الصغيرة، بذرة ورا بذرة.',
    'createAccount': 'حساب جديد',
    'haveAccount': 'تسجيل الدخول',
    'signUpTitle': 'أنشئ\nحسابك',
    'signUpAccent': 'مزرعتك بانتظارك',
    'fullName': 'الاسم الكامل',
    'fullNameHint': 'نورة',
    'email': 'البريد الإلكتروني',
    'emailHint': 'name@example.com',
    'password': 'كلمة المرور',
    'passwordHint': '٨ أحرف على الأقل',
    'createButton': 'إنشاء الحساب',
    'alreadyHaveAccount': 'عندك حساب؟',
    'logInLink': 'سجّل دخولك',
    'loginTitle': 'أهلًا\nمن جديد!',
    'loginAccent': 'نباتاتك اشتاقت لك',
    'forgotPassword': 'نسيت كلمة المرور؟',
    'loginButton': 'تسجيل الدخول',
    'newHere': 'جديد في إثمار؟',
    'createAccountLink': 'أنشئ حساب',
    'errNameRequired': 'اكتب اسمك عشان نسلّم عليك',
    'errEmailRequired': 'اكتب بريدك الإلكتروني',
    'errEmailInvalid': 'البريد الإلكتروني غير صحيح',
    'errPasswordRequired': 'اكتب كلمة المرور',
    'errPasswordShort': 'استخدم ٨ أحرف على الأقل',
    'showPassword': 'إظهار كلمة المرور',
    'hidePassword': 'إخفاء كلمة المرور',
    'back': 'رجوع',
    'accountCreated': 'تم إنشاء حسابك. أهلًا بك في إثمار!',
    'resetSoon': 'استعادة كلمة المرور قريبًا',
    'homeHello': 'أهلًا',
    'homeFriend': 'يا صديقي',
    'homeTitle': 'حديقتك\nتقريبًا جاهزة',
    'homeBody': 'قاعدين نزرع باقي الشاشات. ارجع لنا قريب!',
    'logOut': 'تسجيل الخروج',
  };
}

class S {
  S(this._map);
  final Map<String, String> _map;

  static S of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return S(code == 'ar' ? AppStrings.ar : AppStrings.en);
  }

  String t(String key) => _map[key] ?? key;

  String get languageSwitch => t('languageSwitch');
  String get welcomeTitle => t('welcomeTitle');
  String get welcomeBody => t('welcomeBody');
  String get createAccount => t('createAccount');
  String get haveAccount => t('haveAccount');
  String get signUpTitle => t('signUpTitle');
  String get signUpAccent => t('signUpAccent');
  String get fullName => t('fullName');
  String get fullNameHint => t('fullNameHint');
  String get email => t('email');
  String get emailHint => t('emailHint');
  String get password => t('password');
  String get passwordHint => t('passwordHint');
  String get createButton => t('createButton');
  String get alreadyHaveAccount => t('alreadyHaveAccount');
  String get logInLink => t('logInLink');
  String get loginTitle => t('loginTitle');
  String get loginAccent => t('loginAccent');
  String get forgotPassword => t('forgotPassword');
  String get loginButton => t('loginButton');
  String get newHere => t('newHere');
  String get createAccountLink => t('createAccountLink');
  String get errNameRequired => t('errNameRequired');
  String get errEmailRequired => t('errEmailRequired');
  String get errEmailInvalid => t('errEmailInvalid');
  String get errPasswordRequired => t('errPasswordRequired');
  String get errPasswordShort => t('errPasswordShort');
  String get showPassword => t('showPassword');
  String get hidePassword => t('hidePassword');
  String get back => t('back');
  String get accountCreated => t('accountCreated');
  String get resetSoon => t('resetSoon');
  String get homeHello => t('homeHello');
  String get homeFriend => t('homeFriend');
  String get homeTitle => t('homeTitle');
  String get homeBody => t('homeBody');
  String get logOut => t('logOut');
}
