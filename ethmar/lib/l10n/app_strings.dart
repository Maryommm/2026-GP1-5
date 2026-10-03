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
    'username': 'Username',
    'usernameHint': 'noora_22',
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
    'errUsernameRequired': 'Pick a username so we can say hi',
    'errUsernameInvalid':
        'Use 3–20 letters, numbers, dots or underscores (no spaces)',
    'errUsernameTaken': 'Username is already taken.',
    'errEmailRequired': 'Enter your email',
    'errEmailInvalid':
        "That email doesn't look right. Try something like name@example.com",
    'errPasswordRequired': 'Enter your password',
    'errPasswordWeak': 'Use at least 8 characters, with a capital letter, a number and a special character (like ! or @)',
    'showPassword': 'Show password',
    'hidePassword': 'Hide password',
    'back': 'Back',
    'accountCreated': 'Account created. Welcome to Ethmar!',
    'resetSoon': "Password reset is coming soon",
    'resetTitle': 'Forgot your\npassword?',
    'resetAccent': "we'll get you back in",
    'sendResetLink': 'Send reset link',
    'backToLogin': 'Back to Login',
    'resetLinkSent': 'If an account exists for this email, you will receive a password reset link.',
    'errEmailNotRegistered': "We couldn't find an account with that email",
    'verifyEmail': 'Verify email',
    'verifySoon': 'Email verification is coming soon',
    'verificationLinkSent': 'Verification link sent! Check your inbox',
    'emailVerified': 'Your email has been verified',
    'errVerifyEmailFirst':
        'Verify your email first. Check your inbox for the link',
    'errEmailAlreadyInUse':
        'That email is already in use. Log in or reset your password',
    'errTooManyRequests':
        'Too many attempts. Please wait a little and try again',
    'errNetwork': 'Connection problem. Check your internet and try again',
    'errAuthGeneral': "We couldn't complete the request. Please try again",
    'errAuthSessionMismatch': 'The current account session does not match this sign-up attempt. Please try again',
    'errInvalidCredentials': "That email or password doesn't match. Try again",
    'errProfileCreate':
        "We couldn't finish setting up your profile. Please try again",
    'errProfileConflict': 'The registration data for this account is inconsistent. Please contact support',
    'errProfileMissing': 'Your Ethmar profile is missing. Please complete account creation first',
    'errProfileLoad': "We couldn't load your Ethmar profile. Please try again",
    'errLogout': "We couldn't log you out. Please try again",
    'homeHello': 'Hello',
    'homeFriend': 'friend',
    'homeTitle': 'Your garden is\nalmost ready',
    'homeBody': "We're planting the next screens. Come back soon!",
    'logOut': 'Log Out',
    'cropPreviewLink': 'Try crop recommendations (preview)',
    'cropTitle': 'Crops picked\nfor you',
    'cropAccent': 'based on your weather today',
    'cropLoading1': 'Finding where you are…',
    'cropLoading2': 'Checking today\'s weather…',
    'cropLoading3': 'Picking your perfect crops…',
    'cropHumidity': 'humidity',
    'cropTempRange': 'Temperature',
    'cropIrrigation': 'Watering',
    'cropSeason': 'Season',
    'cropHarvest': 'Harvest in',
    'cropDays': 'days',
    'cropError': "We couldn't get your recommendations. Please try again",
    'tryAgain': 'Try again',
    'homeGoodMorning': 'Good morning,',
    'homeGoodAfternoon': 'Good afternoon,',
    'homeGoodEvening': 'Good evening,',
    'homeMotivation': 'every big harvest starts small',
    'homeStreakDays': '0 days streak',
    'homeStreakHint': 'Add a plant to start your streak',
    'homeAddPlant': 'Add Plant',
    'homeWhatToPlant': 'What to plant?',
    'homeScanPlant': 'Scan plant',
    'homeNearMe': 'Near me',
    'homeAskEthmar': 'Ask Ethmar',
    'navHome': 'Home',
    'navDailyTasks': 'Daily Tasks',
    'navVirtualFarm': 'Virtual Farm',
    'navLeaderboard': 'Leaderboard',
    'profile': 'Profile',
    'editProfile': 'Edit Profile',
    'statPlants': 'Plants',
    'statRank': 'Rank',
    'editProfileTitle': 'Edit your profile',
    'editProfileAccent': 'keep it fresh',
    'takePhoto': 'Take Photo',
    'chooseFromGallery': 'Choose from Gallery',
    'save': 'Save',
    'cancel': 'Cancel',
    'profileUpdated': 'Profile updated successfully.',
    'errUsernameInUse':
        'This username is already in use. Please choose another one.',
    'errProfileUpdate': "We couldn't update your profile. Please try again.",
    'discardChangesTitle': 'Discard changes?',
    'keepEditing': 'Keep editing',
    'discard': 'Discard',
    'weatherCityRiyadh': 'Riyadh',
    'weatherSunny': 'Sunny',
    'weatherCloudy': 'Cloudy',
    'weatherRainy': 'Rainy',
    'weatherWindy': 'Windy',
    'weatherCold': 'Cold',
  };

  static const Map<String, String> ar = {
    'languageSwitch': 'English',
    'welcomeTitle': 'أهلًا بك في إثمار!',
    'welcomeBody': 'ازرع مزرعتك الصغيرة، بذرة ورا بذرة.',
    'createAccount': 'حساب جديد',
    'haveAccount': 'تسجيل الدخول',
    'signUpTitle': 'أنشئ\nحسابك',
    'signUpAccent': 'مزرعتك بانتظارك',
    'username': 'اسم المستخدم',
    'usernameHint': 'noora_22',
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
    'errUsernameRequired': 'اختر اسم مستخدم عشان نسلّم عليك',
    'errUsernameInvalid':
        'استخدم من ٣ إلى ٢٠ حرف إنجليزي أو رقم أو نقطة أو _ (بدون مسافات)',
    'errUsernameTaken': 'اسم المستخدم مستخدم بالفعل.',
    'errEmailRequired': 'اكتب بريدك الإلكتروني',
    'errEmailInvalid':
        'البريد الإلكتروني غير صحيح. جرّب مثلًا name@example.com',
    'errPasswordRequired': 'اكتب كلمة المرور',
    'errPasswordWeak': 'استخدم ٨ أحرف على الأقل، فيها حرف إنجليزي كبير ورقم ورمز خاص (مثل ! أو @)',
    'showPassword': 'إظهار كلمة المرور',
    'hidePassword': 'إخفاء كلمة المرور',
    'back': 'رجوع',
    'accountCreated': 'تم إنشاء حسابك. أهلًا بك في إثمار!',
    'resetSoon': 'استعادة كلمة المرور قريبًا',
    'resetTitle': 'نسيت\nكلمة المرور؟',
    'resetAccent': 'نرجّعك لمزرعتك',
    'sendResetLink': 'أرسل رابط الاستعادة',
    'backToLogin': 'رجوع لتسجيل الدخول',
    'resetLinkSent': 'إذا كان هناك حساب مرتبط بهذا البريد الإلكتروني، فسيصلك رابط لإعادة تعيين كلمة المرور.',
    'errEmailNotRegistered': 'ما لقينا حساب بهذا البريد الإلكتروني',
    'verifyEmail': 'تأكيد البريد الإلكتروني',
    'verifySoon': 'تأكيد البريد الإلكتروني قريبًا',
    'verificationLinkSent': 'أرسلنا رابط التحقق! تحقق من بريدك الإلكتروني',
    'emailVerified': 'تم تأكيد بريدك الإلكتروني',
    'errVerifyEmailFirst':
        'أكّد بريدك الإلكتروني أولًا. الرابط وصلك على الإيميل',
    'errEmailAlreadyInUse':
        'هذا البريد مستخدم بالفعل. سجّل الدخول أو استعد كلمة المرور',
    'errTooManyRequests': 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى',
    'errNetwork': 'توجد مشكلة في الاتصال. تحقق من الإنترنت وحاول مرة أخرى',
    'errAuthGeneral': 'تعذّر إكمال الطلب. حاول مرة أخرى',
    'errAuthSessionMismatch':
        'جلسة الحساب الحالية لا تطابق محاولة التسجيل هذه. حاول مرة أخرى',
    'errInvalidCredentials':
        'البريد الإلكتروني أو كلمة المرور غير صحيحة. حاول مرة ثانية',
    'errProfileCreate': 'تعذّر إكمال إعداد ملفك الشخصي. حاول مرة أخرى',
    'errProfileConflict': 'بيانات تسجيل هذا الحساب غير متسقة. تواصل مع الدعم',
    'errProfileMissing':
        'ملفك الشخصي في إثمار غير موجود. أكمل إنشاء الحساب أولًا',
    'errProfileLoad': 'تعذّر تحميل ملفك الشخصي في إثمار. حاول مرة أخرى',
    'errLogout': 'تعذّر تسجيل الخروج. حاول مرة أخرى',
    'homeHello': 'أهلًا',
    'homeFriend': 'يا صديقي',
    'homeTitle': 'حديقتك\nتقريبًا جاهزة',
    'homeBody': 'قاعدين نزرع باقي الشاشات. ارجع لنا قريب!',
    'logOut': 'تسجيل الخروج',
    'cropPreviewLink': 'جرّب اقتراح المحاصيل (تجريبي)',
    'cropTitle': 'محاصيل\nاخترناها لك',
    'cropAccent': 'حسب طقسك اليوم',
    'cropLoading1': 'نحدد موقعك…',
    'cropLoading2': 'نشيّك على طقس اليوم…',
    'cropLoading3': 'نختار لك أنسب المحاصيل…',
    'cropHumidity': 'رطوبة',
    'cropTempRange': 'درجة الحرارة',
    'cropIrrigation': 'الري',
    'cropSeason': 'الموسم',
    'cropHarvest': 'الحصاد بعد',
    'cropDays': 'يوم',
    'cropError': 'تعذّر جلب الاقتراحات. حاول مرة أخرى',
    'tryAgain': 'حاول مرة أخرى',
    'homeGoodMorning': 'صباح الخير،',
    'homeGoodAfternoon': 'مساء الخير،',
    'homeGoodEvening': 'مساء الخير،',
    'homeMotivation': 'كل حصاد كبير يبدأ صغير',
    'homeStreakDays': '٠ أيام متتالية',
    'homeStreakHint': 'أضف نبتة عشان تبدأ سلسلتك',
    'homeAddPlant': 'أضف نبتة',
    'homeWhatToPlant': 'وش أزرع؟',
    'homeScanPlant': 'افحص نبتتك',
    'homeNearMe': 'قريب مني',
    'homeAskEthmar': 'اسأل إثمار',
    'navHome': 'الرئيسية',
    'navDailyTasks': 'المهام اليومية',
    'navVirtualFarm': 'المزرعة الافتراضية',
    'navLeaderboard': 'المتصدرون',
    'profile': 'الملف الشخصي',
    'editProfile': 'تعديل الملف الشخصي',
    'statPlants': 'النباتات',
    'statRank': 'الترتيب',
    'editProfileTitle': 'عدّل ملفك',
    'editProfileAccent': 'خلّه دايم جديد',
    'takePhoto': 'التقط صورة',
    'chooseFromGallery': 'اختر من المعرض',
    'save': 'حفظ',
    'cancel': 'إلغاء',
    'profileUpdated': 'تم تحديث الملف الشخصي بنجاح.',
    'errUsernameInUse': 'اسم المستخدم مستخدم بالفعل. الرجاء اختيار اسم آخر.',
    'errProfileUpdate': 'تعذّر تحديث ملفك الشخصي. حاول مرة أخرى.',
    'discardChangesTitle': 'هل تريد تجاهل التغييرات؟',
    'keepEditing': 'متابعة التعديل',
    'discard': 'تجاهل',
    'weatherCityRiyadh': 'الرياض',
    'weatherSunny': 'مشمس',
    'weatherCloudy': 'غائم',
    'weatherRainy': 'ممطر',
    'weatherWindy': 'عاصف',
    'weatherCold': 'بارد',
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
  String get username => t('username');
  String get usernameHint => t('usernameHint');
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
  String get errUsernameRequired => t('errUsernameRequired');
  String get errUsernameInvalid => t('errUsernameInvalid');
  String get errUsernameTaken => t('errUsernameTaken');
  String get errEmailRequired => t('errEmailRequired');
  String get errEmailInvalid => t('errEmailInvalid');
  String get errPasswordRequired => t('errPasswordRequired');
  String get errPasswordWeak => t('errPasswordWeak');
  String get showPassword => t('showPassword');
  String get hidePassword => t('hidePassword');
  String get back => t('back');
  String get accountCreated => t('accountCreated');
  String get resetSoon => t('resetSoon');
  String get resetTitle => t('resetTitle');
  String get resetAccent => t('resetAccent');
  String get sendResetLink => t('sendResetLink');
  String get backToLogin => t('backToLogin');
  String get resetLinkSent => t('resetLinkSent');
  String get errEmailNotRegistered => t('errEmailNotRegistered');
  String get verifyEmail => t('verifyEmail');
  String get verifySoon => t('verifySoon');
  String get verificationLinkSent => t('verificationLinkSent');
  String get emailVerified => t('emailVerified');
  String get errVerifyEmailFirst => t('errVerifyEmailFirst');
  String get errEmailAlreadyInUse => t('errEmailAlreadyInUse');
  String get errTooManyRequests => t('errTooManyRequests');
  String get errNetwork => t('errNetwork');
  String get errAuthGeneral => t('errAuthGeneral');
  String get errAuthSessionMismatch => t('errAuthSessionMismatch');
  String get errInvalidCredentials => t('errInvalidCredentials');
  String get errProfileCreate => t('errProfileCreate');
  String get errProfileConflict => t('errProfileConflict');
  String get errProfileMissing => t('errProfileMissing');
  String get errProfileLoad => t('errProfileLoad');
  String get errLogout => t('errLogout');
  String get homeHello => t('homeHello');
  String get homeFriend => t('homeFriend');
  String get homeTitle => t('homeTitle');
  String get homeBody => t('homeBody');
  String get logOut => t('logOut');
  String get cropPreviewLink => t('cropPreviewLink');
  String get cropTitle => t('cropTitle');
  String get cropAccent => t('cropAccent');
  List<String> get cropLoadingSteps =>
      [t('cropLoading1'), t('cropLoading2'), t('cropLoading3')];
  String get cropHumidity => t('cropHumidity');
  String get cropTempRange => t('cropTempRange');
  String get cropIrrigation => t('cropIrrigation');
  String get cropSeason => t('cropSeason');
  String get cropHarvest => t('cropHarvest');
  String get cropDays => t('cropDays');
  String get cropError => t('cropError');
  String get tryAgain => t('tryAgain');
  String get homeGoodMorning => t('homeGoodMorning');
  String get homeGoodAfternoon => t('homeGoodAfternoon');
  String get homeGoodEvening => t('homeGoodEvening');
  String get homeMotivation => t('homeMotivation');
  String get homeStreakDays => t('homeStreakDays');
  String get homeStreakHint => t('homeStreakHint');
  String get homeAddPlant => t('homeAddPlant');
  String get homeWhatToPlant => t('homeWhatToPlant');
  String get homeScanPlant => t('homeScanPlant');
  String get homeNearMe => t('homeNearMe');
  String get homeAskEthmar => t('homeAskEthmar');
  String get navHome => t('navHome');
  String get navDailyTasks => t('navDailyTasks');
  String get navVirtualFarm => t('navVirtualFarm');
  String get navLeaderboard => t('navLeaderboard');
  String get profile => t('profile');
  String get editProfile => t('editProfile');
  String get statPlants => t('statPlants');
  String get statRank => t('statRank');
  String get editProfileTitle => t('editProfileTitle');
  String get editProfileAccent => t('editProfileAccent');
  String get takePhoto => t('takePhoto');
  String get chooseFromGallery => t('chooseFromGallery');
  String get save => t('save');
  String get cancel => t('cancel');
  String get profileUpdated => t('profileUpdated');
  String get errUsernameInUse => t('errUsernameInUse');
  String get errProfileUpdate => t('errProfileUpdate');
  String get discardChangesTitle => t('discardChangesTitle');
  String get keepEditing => t('keepEditing');
  String get discard => t('discard');
  String get weatherCityRiyadh => t('weatherCityRiyadh');
  String get weatherSunny => t('weatherSunny');
  String get weatherCloudy => t('weatherCloudy');
  String get weatherRainy => t('weatherRainy');
  String get weatherWindy => t('weatherWindy');
  String get weatherCold => t('weatherCold');
}
