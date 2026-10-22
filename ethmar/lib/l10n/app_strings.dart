import 'package:flutter/widgets.dart';

import '../models/crop_recommendation.dart' show MatchBand, ModelNote;

class AppStrings {
  AppStrings._();

  static const Map<String, String> en = {
    'languageSwitch': 'العربية',
    'welcomeTitle': 'Welcome to Ethmar!',
    'welcomeBody': 'Start your little farm now!',
    'createAccount': 'Sign Up',
    'haveAccount': 'Log In',
    'signUpTitle': 'Sign Up',
    'username': 'Username',
    'usernameHint': 'Enter your username',
    'email': 'Email',
    'emailHint': 'name@example.com',
    'password': 'Password',
    'passwordHint': 'Enter your password',
    'createButton': 'Sign Up',
    'alreadyHaveAccount': 'Already have an account?',
    'logInLink': 'Log In',
    'loginTitle': 'Log In',
    'forgotPassword': 'Forgot password?',
    'loginButton': 'Log In',
    'newHere': "Don't have an account?",
    'createAccountLink': 'Sign Up',
    'errUsernameRequired': 'Pick a username so we can say hi',
    'errUsernameTaken': 'Username is already taken.',
    'errUsernameCheckFailed':
        "We couldn't check this username. Check your connection.",
    'errEmailRequired': 'Enter your email',
    'errEmailInvalid':
        "That email doesn't look right. Try something like name@example.com",
    'errPasswordRequired': 'Enter your password',
    'errPasswordNeeds': 'Your password needs',
    'errPasswordLength': 'at least 8 characters',
    'errPasswordUpper': 'a capital letter',
    'errPasswordDigit': 'a number',
    'errPasswordSpecial': 'a special character (like ! or @)',
    'showPassword': 'Show password',
    'hidePassword': 'Hide password',
    'back': 'Back',
    'accountCreated': 'Account created. Welcome to Ethmar!',
    'resetTitle': 'Forgot your\npassword?',
    'sendResetLink': 'Send reset link',
    'backToLogin': 'Back to Login',
    'resetLinkSent': 'If an account exists for this email, you will receive a password reset link.',
    'emailVerified': 'Your email has been verified',
    'verifyDialogTitle': 'Check your email',
    'verifyDialogBody': "We sent a verification link to {email}. Open it to verify your account. Can't find it? Check your spam folder.",
    'verifyDialogWaiting': 'Waiting for verification…',
    'resendEmail': 'Resend email',
    'verificationResent': 'Sent again! Check your inbox',
    'emailNotVerifiedTitle': 'Email not verified',
    'verificationRecoveryBody': 'The email for this account ({email}) is not verified. The previous link may have expired. Resend a fresh verification email, open it, then check again.',
    'checkVerification': 'Check verification / continue',
    'verificationStillPending': 'Your email is still not verified. Open the latest verification email, then try again.',
    'errSignUpUnfinished':
        "Your sign up wasn't finished, so it was cancelled. Please sign up again",
    'errSignUpUnfinishedLogIn':
        "Your sign up wasn't finished. Log in to continue",
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
    'errProfileLoad': "We couldn't load your Ethmar profile. Please try again",
    'errLogout': "We couldn't log you out. Please try again",
    'homeFriend': 'friend',
    'logOut': 'Log Out',
    'cropTitle': 'Crops Picked For You',
    'cropAccent': "Based on your area's climate this month",
    'cropCatHerb': 'Herb',
    'cropCatLegume': 'Legume',
    'cropCatRoot': 'Root veg',
    'cropCatVegetable': 'Veg',
    'cropCatFruit': 'Fruit',
    'cropLoading1': 'Finding where you are…',
    'cropLoading2': "Checking your area's climate…",
    'cropLoading3': 'Picking your perfect crops…',
    'cropTempRange': 'Best Temperature',
    'cropWaterNeed': 'Water Need',
    'cropBestTime': 'Best Time to Plant',
    'cropHarvest': 'Harvest In',
    'cropGrowsTo': 'Grows to',
    'cropDays': 'days',
    'cropMeters': 'm',
    'cropAllYear': 'All year',
    'cropBand_excellent': 'Great',
    'cropBand_good': 'Good match',
    'cropBand_fair': 'Fair match',
    'cropWater_low': 'Low',
    'cropWater_medium': 'Medium',
    'cropWater_high': 'High',
    'cropNoCrops': 'No crops suit your area this month. Check again next month',
    'cropError': "We couldn't get your recommendations. Please try again",
    'cropErrorSignIn': 'Please log in again to see your recommendations',
    'cropErrorClimate':
        "We couldn't reach the climate service. Please try again later",
    'cropErrorOffline':
        "You're not connected to the internet. Please try again later",
    'cropMoreFailed': "We couldn't load more crops",
    'cropLocationDenied':
        'We need your location to suggest crops for your area. Allow location access to see your recommendations',
    'cropLocationBlocked':
        "Location access is off for Ethmar. Allow it in your phone's settings to see crops for your area",
    'cropLocationOff':
        "Your phone's location is turned off. Turn it on to see crops for your area",
    'cropLocationUnavailable':
        "We couldn't find your location. Please try again",
    'cropOpenSettings': 'Open settings',
    'cropPlantingQuestion': 'Where will you plant?',
    'cropSetupWhy': 'Your answers help us pick crops that suit you',
    'cropSetupStep': 'Question {n} of 3',
    'cropNoCropsLowSun':
        'The sunlight in your spot is the reason: most crops need more direct sun than it gets. Try a sunnier spot, such as a balcony or a roof',
    'cropFewInShade':
        'Only a few crops grow with less than 3 hours of sun a day. A sunnier spot gives you more choices',
    'cropChangeAnswers': 'Change my answers',
    'cropPlantingPot': 'In a pot',
    'cropPlantingPotHint': 'With bought potting soil',
    'cropPlantingGround': 'In the ground',
    'cropPlantingGroundHint': 'In your garden or yard soil',
    'cropSunQuestion': 'How much sun will they get?',
    'cropSunFull': 'Full sun',
    'cropSunFullHint': '6 hours or more of direct sun a day',
    'cropSunPartial': 'Partial sun',
    'cropSunPartialHint': '3 to 6 hours of direct sun a day',
    'cropSunShade': 'Mostly shade',
    'cropSunShadeHint': 'Less than 3 hours of direct sun a day',
    'cropWaterQuestion': 'How often will you water?',
    'cropWaterLow': 'Low',
    'cropWaterLowHint': 'Once a week or less',
    'cropWaterMedium': 'Medium',
    'cropWaterMediumHint': 'A few times a week',
    'cropWaterHigh': 'High',
    'cropWaterHighHint': 'Every day, keeping the soil moist',
    'month1': 'Jan',
    'month2': 'Feb',
    'month3': 'Mar',
    'month4': 'Apr',
    'month5': 'May',
    'month6': 'Jun',
    'month7': 'Jul',
    'month8': 'Aug',
    'month9': 'Sep',
    'month10': 'Oct',
    'month11': 'Nov',
    'month12': 'Dec',
    'listJoin': ', ',
    // Reasons and warnings from the model (codes in recommender/scripts/scoring.py).
    'note_temp_ok': 'The weather in your area suits it all season',
    'note_rain_ok': 'The rain in your area covers its water needs',
    'note_light_ok': 'The sunlight in your spot suits it',
    'note_water_ok': 'How often you water suits it',
    'note_water_more_often':
        'Needs watering a few times a week, more often than you plan',
    'note_water_less_often':
        'Likes dry soil: let the soil dry out between waterings',
    'note_needs_acidic_soil':
        'Your soil is too alkaline for it: grow it in a pot with potting soil, or mix garden sulfur into the soil',
    'note_needs_acidic_mix':
        'Needs an acidic potting mix made for acid-loving plants',
    'note_needs_alkaline_soil':
        'Needs less acidic soil than yours: mix garden lime into the soil',
    'note_plant_next_month': 'Best planted next month, in {month}',
    'note_plant_later': 'Best planted in {month}',
    'note_needs_shade':
        'Shade it in {months}: use shade cloth or move the pot inside',
    'note_needs_cover':
        'Cover it on cold nights in {months}, or bring the pot inside',
    'note_too_cool': 'Grows slowly in {months}, when it is cooler than it likes',
    'note_too_hot': 'Hotter than it likes in {months}: give it afternoon shade',
    'note_too_wet': 'Too much rain here: use raised beds or pots that drain',
    'note_too_dry': 'Your area is dry, so it needs regular watering',
    'note_needs_watering': 'Needs watering between rains',
    'note_needs_wet_soil':
        'Needs soil that stays wet. Grow it in a pot standing in water',
    'note_light_too_strong':
        'Your spot is too sunny for it: shade it, especially in the afternoon',
    'cropSwipeHint': 'Swipe to explore crop categories',
    'tryAgain': 'Try again',
    'cropShowTips': 'Show {n} more tips',
    'cropHideTips': 'Show fewer tips',
    'startupErrorTitle': "We couldn't connect",
    'startupErrorBody':
        'Check your internet connection and try again in a moment.',
    'homeGoodMorning': 'Good morning,',
    'homeGoodAfternoon': 'Good afternoon,',
    'homeGoodEvening': 'Good evening,',
    // Home slogans, one shown per day (see daily_slogan_service.dart).
    'homeSlogan1': "Tomorrow's Harvest Begins with Today's Seed",
    'homeSlogan2': 'Plant Today, Change Tomorrow',
    'homeSlogan3': 'Beautiful Things Take Time to Grow',
    // Streak card states on Home.
    'streakNotStartedTitle': '0 day streak',
    'streakNotStartedHint': 'Add your first plant and start your streak now!',
    'streakActiveTitle': '{n} day streak',
    'streakActiveTitleOne': '1 day streak',
    'streakActiveTitleTwo': '2 day streak',
    'streakActiveTitleMany': '{n} day streak',
    'streakActiveHint':
        'Great job! Keep caring for your plants to maintain your streak.',
    'streakLostTitle': 'Streak lost',
    'streakLostHint': 'Take care of your plants and start your streak again.',
    'homeAddPlant': 'Add Plant',
    'homeNearMe': 'Near me',
    'navHome': 'Home',
    'navDailyTasks': 'Daily Tasks',
    // Daily Tasks screen
    'dailyTasksSubtitle': 'Care for your plants today',
    'dailyProgress': 'Daily Progress',
    'dailyProgressOf': '{done} of {total} tasks completed',
    'todaysTasks': "Today's Tasks",
    'taskWatering': 'Watering',
    'taskFertilizing': 'Fertilizing',
    'statusCompleted': 'Completed',
    'statusOverdue': 'Overdue',
    'statusUpcoming': 'Upcoming',
    'taskMarkDone': 'Mark as done',
    // Today's date, e.g. "Wednesday, October 21".
    'todayDate': '{weekday}, {month} {day}',
    'weekday1': 'Monday',
    'weekday2': 'Tuesday',
    'weekday3': 'Wednesday',
    'weekday4': 'Thursday',
    'weekday5': 'Friday',
    'weekday6': 'Saturday',
    'weekday7': 'Sunday',
    'monthLong1': 'January',
    'monthLong2': 'February',
    'monthLong3': 'March',
    'monthLong4': 'April',
    'monthLong5': 'May',
    'monthLong6': 'June',
    'monthLong7': 'July',
    'monthLong8': 'August',
    'monthLong9': 'September',
    'monthLong10': 'October',
    'monthLong11': 'November',
    'monthLong12': 'December',
    'navVirtualFarm': 'Your Farm',
    // Home feature cards and the Ask Thamoor tab (Thamoor is the mascot).
    'homeCardRecommended': 'Recommended',
    'homeCardNearMe': 'Ethmar Map',
    'homeCardLeaderboard': 'Leaderboard',
    'homeCardAddPlant': 'Grow a Plant',
    'homeCardDiagnosis': 'Check Your Plant',
    'navAskThamoor': 'Ask Thamoor',
    'profile': 'Profile',
    'editProfile': 'Edit Profile',
    // Profile screen
    'memberSince': 'Member since {date}',
    'statMyPlants': 'Your Plants',
    'statMyRank': 'Your Rank',
    'settingsTitle': 'Settings',
    'settingsLanguage': 'Language',
    'aboutEthmar': 'About Ethmar',
    'contactEthmar': 'Contact Us',
    'chooseLanguage': 'Choose language',
    'languageArabic': 'العربية',
    'languageEnglish': 'English',
    'logOutConfirmTitle': 'Log out?',
    'logOutConfirmBody': 'Are you sure you want to log out of your account?',
    // About Ethmar
    'aboutTagline': 'Your Personal Agricultural Assistant',
    'aboutWhatTitle': 'What Is Ethmar?',
    'aboutWhatBody':
        'Ethmar is a home gardening application that allows users to explore crops suited to their local climate, organize plant care tasks, and track plant growth. It offers a range of smart and interactive features that help users manage their home gardening activities.',
    'aboutOffersTitle': 'Key Features',
    'aboutCard1Title': 'Crop Selection and Nearby Services',
    'aboutCard1Body':
        'Ethmar provides crop recommendations based on the local climate, along with an interactive map that helps users find nearby nurseries, agricultural supply stores, and related services.',
    'aboutCard2Title': 'Plant Care and Monitoring',
    'aboutCard2Body':
        'The application provides watering and fertilizing reminders, weather alerts for conditions that may affect plants, and tools for tracking plant growth. It also includes image-based plant disease detection and an AI assistant that answers gardening-related questions.',
    'aboutCard3Title': 'Interactive Gardening Experience',
    'aboutCard3Body':
        'Ethmar includes a virtual garden where users can view their plants and track their growth, along with a leaderboard that adds an interactive and competitive element to home gardening and encourages users to continue caring for their plants.',
    'aboutGoalTitle': 'Our Goal',
    'aboutGoalBody':
        'Ethmar aims to encourage home gardening and increase its adoption by providing an integrated experience that brings together the services and features users need in one application, making growing and caring for plants easier and more organized.',
    // Contact Ethmar
    'contactEmailTitle': 'Email',
    'contactXTitle': 'X Platform',
    'errOpenEmail': "Couldn't open an email app. The address has been copied.",
    'errOpenLink': "Couldn't open the link. It has been copied.",
    'takePhoto': 'Take Photo',
    'chooseFromGallery': 'Choose from Gallery',
    'deletePhoto': 'Delete Photo',
    'profilePhotoUploaded': 'Profile photo uploaded.',
    'profilePhotoDeleted': 'Profile photo deleted.',
    'errProfilePhotoAuth': 'Your session expired. Sign in again and retry.',
    'errProfilePhotoVerification':
        'Verify your email before changing your photo.',
    'errProfilePhotoType':
        "This image format isn't supported. Please choose a JPEG, PNG or WebP image.",
    'errProfilePhotoSize':
        'The image is larger than 5 MB. Please choose a smaller image.',
    'errProfilePhotoRateLimit':
        'Too many photo requests. Wait a minute and retry.',
    'errProfilePhotoServer':
        'The image service is unavailable. Try again later.',
    'errProfilePhotoSave':
        'The photo changed, but your profile could not be updated. Try again.',
    'errImageRead': 'Unable to read the image. Please try again.',
    'errCameraOpen': 'Unable to open the camera. Please try again.',
    'errPhotoCapture': 'Unable to take the photo. Please try again.',
    'errPhotoSelect': 'Unable to select the image. Please try again.',
    'errPhotoUpload': 'Unable to upload the photo. Please try again.',
    'errPhotoDelete': 'Unable to delete the photo. Please try again.',
    'cameraAccessTitle': 'Allow camera access',
    'cameraAccessBody':
        'To take a profile photo, turn on camera access for Ethmar in your device settings.',
    'openSettings': 'Open Settings',
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
    'scanTitle': 'Scan a leaf',
    'scanAccent': 'show me the sick leaf up close',
    'scanTipsTitle': 'For the best results',
    'scanTipLight': 'Good light',
    'scanTipOneLeaf': 'One leaf',
    'scanTipStill': 'Hold still',
    'scanCapture': 'Take photo of the leaf',
    'scanNoCamera': "We can't open the camera. Allow camera access, then try again.",
    'scanAnalysing1': 'Looking at your leaf…',
    'scanAnalysing2': 'Checking spots and colour…',
    'scanAnalysing3': 'Finding what it needs…',
    'diagEasyToFix': 'Easy to fix',
    'diagDryLeavesName': 'Dry leaves',
    'diagDryLeavesBody':
        'The leaf edges are drying out. This usually comes from strong sun or not enough water.',
    'scanAnother': 'Scan another leaf',
    'backToHome': 'Back to Home',
    'chatTitle': 'Ethmar is always here to help',
    'chatGreeting': 'Hi {name}, tell me what you need.',
    'chatHint': 'Ask Ethmar…',
    'chatSend': 'Send',
    'close': 'Close',
    'mapAccent': 'nurseries & farm stores around you',
    'mapFilterAll': 'All',
    'mapFilterNurseries': 'Nurseries',
    'mapFilterStores': 'Farm stores',
    'mapNursery': 'Nursery',
    'mapStore': 'Farm store',
    'mapKm': '{km} km',
    'mapLocating': 'Finding your location…',
    'mapDeniedTitle': 'Location access needed',
    'mapDeniedBody':
        'GPS access is required to find nearby services. Allow location access to see the map.',
    'mapAllowLocation': 'Allow location',
    'mapRecenter': 'Show my location',
    'mapYouAreHere': 'You are here',
    'farmTitle': 'My virtual farm',
    'farmAccent': 'your land is ready for its first seed',
    'farmLand': 'Your empty farm land',
    'farmZoomIn': 'Zoom in',
    'farmZoomOut': 'Zoom out',
    'farmResetView': 'Reset view',
    'farmPinchHint': 'Pinch to zoom in and out',
    'farmAddLand': 'Add land',
    'filterAll': 'All',
    'addPlantTitle': 'Add a plant',
    'addPlantStep': 'Step {n} of 2',
    'addPlantChoose': 'Choose your crop',
    'addPlantDetails': 'Name & schedules',
    'addPlantChange': 'Change',
    'addPlantNameLabel': 'Name your plant',
    'addPlantNameHint': 'e.g. Balcony tomato',
    'errPlantNameRequired': 'Give your plant a name',
    'errPlantNameLong': 'Keep the name under 30 characters',
    'addPlantButton': 'Add plant',
    'addPlantLaterHint': 'Schedules are optional. You can set them later.',
    'schedIrrigation': 'Irrigation schedule',
    'schedFertilization': 'Fertilization schedule',
    'schedRepetition': 'Repetition',
    'schedAlarmTime': 'Alarm time',
    'schedLessOften': 'Less often',
    'schedMoreOften': 'More often',
    'repeatEveryDay': 'Every day',
    'repeatEvery2Days': 'Every 2 days',
    'repeatEvery3Days': 'Every 3 days',
    'repeatEveryWeek': 'Every week',
    'repeatEvery2Weeks': 'Every 2 weeks',
    'repeatEveryMonth': 'Every month',
    'summaryTitle': 'Ready to plant?',
    'summaryIrrigation': 'Irrigation',
    'summaryFertilization': 'Fertilization',
    'summaryNotSet': 'Not set yet',
    'summaryAt': '{repeat} at {time}',
    'confirm': 'Confirm',
    'plantAdded': '{name} was added to your farm',
    'farmLandFull':
        'Your land is full. Add a new land in your virtual farm to keep planting.',
    'myPlants': 'My plants',
    'myPlantsAccent': 'everything growing on your farm',
    'myPlantsEmpty': 'No plants yet',
    'myPlantsEmptyBody': 'Add your first plant and it will show up here.',
    'plantedToday': 'Planted today',
    'plantDays': '{n} days',
    'plantDayOne': '1 day',
    'daysSincePlanting': 'Days since planting',
    'stagesTitle': 'Stages of growth',
    'stagesEmpty':
        'No pictures yet. Upload one now and then to see how your plant grows.',
    'uploadPicture': 'Upload a picture',
    'notesTitle': 'Add a note?',
    'notesLabel': 'Notes (optional)',
    'notesHint': 'e.g. First flowers appeared',
    'pictureAdded': 'Picture added to the growth timeline',
    'careSchedule': 'Care schedule',
    'edit': 'Edit',
    'scheduleNext': 'Next: {when}',
    'today': 'Today',
    'tomorrow': 'Tomorrow',
    'editPlantTitle': 'Edit plant',
    'plantUpdated': 'Plant updated',
    'leaderboardTitle': 'Leaderboard',
    'leaderboardAccent': "who's growing the most?",
    'rankFirst': "You're #1! Your farm is the biggest of all.",
    'rankTopTen': "You're #{rank} and in the top 10! Keep growing.",
    'rankKeepGoing':
        'You rank #{rank} with {plants}. Keep going to reach the top 10!',
    'plantsCount': '{n} plants',
    'plantsCountOne': '1 plant',
    'you': 'You',
    'rankLabel': 'Rank {rank}',
    'rankToTopTen': '{plants} to go',
  };



  

  static const Map<String, String> ar = {
    'languageSwitch': 'English',
    'welcomeTitle': 'أهلاً بك في إثمار!',
    'welcomeBody': "إبدأ مزرعتك الصغيرة الآن!",
    'createAccount': "إنشاء حساب",
    'haveAccount': 'تسجيل الدخول',
    'signUpTitle': "إنشاء حساب",
    'username': 'اسم المستخدم',
    'usernameHint': ' أدخل اسم المستخدم الخاص بك',
    'email': 'البريد الإلكتروني',
    'emailHint': 'name@example.com',
    'password': 'كلمة المرور',
    'passwordHint': "أدخل كلمة المرور الخاصة بك",
    'createButton': 'إنشاء الحساب',
    'alreadyHaveAccount': ' هل لديك حساب سابق؟',
    'logInLink': 'سجّل دخولك',
    'loginTitle': "تسجيل الدخول",
    'forgotPassword': 'نسيت كلمة المرور؟',
    'loginButton': 'تسجيل الدخول',
    'newHere': "ليس لديك حساب؟",
    'createAccountLink': 'إنشاء حساب',
    'errUsernameRequired': 'أدخل اسم المستخدم',
    'errUsernameTaken': 'اسم المستخدم مستخدم بالفعل.',
    'errUsernameCheckFailed': 'تعذّر التحقق من اسم المستخدم. تأكد من اتصالك.',
    'errEmailRequired': 'ادخل بريدك الإلكتروني',
    'errEmailInvalid':
        'البريد الإلكتروني غير صحيح. يجب ان يكون name@example.com',
    'errPasswordRequired': 'ادخل كلمة المرور',
    'errPasswordNeeds': 'كلمة المرور يجب أن تحتوي',
    'errPasswordLength': '٨ أحرف على الأقل',
    'errPasswordUpper': 'حرف كبير',
    'errPasswordDigit': 'رقم',
    'errPasswordSpecial': 'رمز خاص (مثل ! أو @)',
    'showPassword': 'إظهار كلمة المرور',
    'hidePassword': 'إخفاء كلمة المرور',
    'back': 'عودة',
    'accountCreated': 'تم إنشاء حسابك بنجاح. مرحبًا بك في إثمار!',
    'resetTitle': 'نسيت كلمة المرور؟',
    'sendResetLink': "إعادة التعيين",
    'backToLogin': 'عودة لتسجيل الدخول',
    'resetLinkSent': 'إذا كان هناك حساب مرتبط بهذا البريد الإلكتروني، فسيصلك رابط لإعادة تعيين كلمة المرور.',
    'emailVerified': 'تم تأكيد بريدك الإلكتروني',
    'verifyDialogTitle': 'تحقق من بريدك',
    'verifyDialogBody': 'تم إرسال رابط التحقق إلى {email}. قم بفتحه لتأكيد حسابك. لم تجده؟ قم بالإطلاع على مجلد الرسائل غير المرغوب فيها',
    'verifyDialogWaiting': 'ننتظر تأكيد بريدك…',
    'resendEmail': 'إعادة إرسال الرابط',
    'verificationResent': 'قمنا بالإرسال مرة أخرى! تحقق من بريدك',
    'emailNotVerifiedTitle': 'البريد الإلكتروني غير مؤكّد',
    'verificationRecoveryBody': 'لم يتم تأكيد البريد الإلكتروني لهذا الحساب ({email}). قد تكون صلاحية الرابط السابق انتهت. أعد إرسال رسالة تحقق جديدة، ثم افتحها واضغط على التحقق والمتابعة.',
    'checkVerification': 'التحقق والمتابعة',
    'verificationStillPending': 'لم يتم تأكيد بريدك الإلكتروني بعد. افتح أحدث رسالة تحقق ثم حاول مرة أخرى.',
    'errSignUpUnfinished': 'لم يكتمل تسجيلك، لذلك تم إلغاؤه. سجّل من جديد',
    'errSignUpUnfinishedLogIn': 'لم يكتمل تسجيلك. سجّل الدخول للمتابعة',
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
    'errProfileLoad': 'تعذّر تحميل ملفك الشخصي في إثمار. حاول مرة أخرى',
    'errLogout': 'تعذّر تسجيل الخروج. حاول مرة أخرى',
    'homeFriend': 'يا صديقي',
    'logOut': 'تسجيل الخروج',
    'cropTitle': "توصياتنا لك",
    'cropAccent': 'بناءً على مناخ منطقتك خلال هذا الشهر',
    'cropCatHerb': 'الأعشاب',
    'cropCatLegume': 'البقوليات',
    'cropCatRoot': 'الخضروات الجذرية',
    'cropCatVegetable': 'الخضروات',
    'cropCatFruit': 'الفواكه',
    'cropLoading1': 'جاري تحديد الموقع…',
    'cropLoading2': 'جاري فحص مناخ منطقتك…',
    'cropLoading3': 'جاري اختيار أنسب المحاصيل…',
    'cropTempRange': 'أفضل درجة حرارة',
    'cropWaterNeed': 'احتياج الماء',
    'cropBestTime': 'أفضل وقت للزراعة',
    'cropHarvest': 'الحصاد بعد',
    'cropGrowsTo': 'ينمو حتى',
    'cropDays': 'يوم',
    'cropMeters': 'م',
    'cropAllYear': 'طوال السنة',
    'cropBand_excellent': "ممتاز",
    'cropBand_good': 'مناسب',
    'cropBand_fair': 'مناسب نوعًا ما',
    'cropWater_low': "قليل",
    'cropWater_medium': "متوسط",
    'cropWater_high': "عالي",
    'cropNoCrops': 'لا يوجد محاصيل تناسب منطقتك هذا الشهر. حاول مرة أخرى قريبًا',
    'cropError': 'تعذّر جلب الاقتراحات. حاول مرة أخرى',
    'cropErrorSignIn': 'قم بتسجيل الدخول مرة أخرى للتمكن من الاطلاع على الاقتراحات',
    'cropErrorClimate': 'تعذّر الوصول لبيانات المناخ. حاول مرة أخرى',
    'cropErrorOffline': 'أنت غير متصل بالإنترنت. حاول مرة أخرى',
    'cropMoreFailed': 'تعذّر تحميل المزيد من المحاصيل',
    'cropLocationDenied':
        'لم نتمكن من الوصول لبيانات موقعك. قم بالسماح للتطبيق بالوصول لبيانات الموقع لتتمكن من الإطلاع على التوصيات',
    'cropLocationBlocked':
        'أذونات الوصول للموقع مغلقة. قم بالسماح بالوصول لبيانات الموقع من الإعدادات لتتمكن من الاطلاع على التوصيات المناسبة لمنطقتك',
    'cropLocationOff':
        'خدمة الموقع مغلقة في جهازك. قم بتشغيلها لتتمكن من الاطلاع على التوصيات المناسبة لمنطقتك',
    'cropLocationUnavailable': 'لم نتمكن من تحديد موقعك. قم بالمحاولة مرة أخرى',
    'cropOpenSettings': 'فتح الإعدادات',
    'cropPlantingQuestion': 'أين ستزرع؟',
    'cropSetupWhy': 'إجاباتك تساعدنا في اختيار محاصيل تناسبك',
    'cropSetupStep': 'السؤال {n} من 3',
    'cropNoCropsLowSun':
        'السبب هو كمية الشمس في مكانك: أغلب المحاصيل تحتاج شمسًا مباشرة أكثر مما يصل إليه. جرّب مكانًا مشمسًا أكثر مثل الشرفة أو السطح',
    'cropFewInShade':
        'قليل من المحاصيل ينمو بأقل من 3 ساعات شمس يوميًا. المكان المشمس أكثر يمنحك خيارات أكثر',
    'cropChangeAnswers': 'تغيير إجاباتي',
    'cropPlantingPot': 'في أصيص',
    'cropPlantingPotHint': 'بتربة زراعية جاهزة',
    'cropPlantingGround': 'في الأرض',
    'cropPlantingGroundHint': 'في تربة الحديقة أو الفناء',
    'cropSunQuestion': 'كم ستحصل النباتات على شمس؟',
    'cropSunFull': 'شمس كاملة',
    'cropSunFullHint': '6 ساعات أو أكثر من الشمس المباشرة يوميًا',
    'cropSunPartial': 'شمس جزئية',
    'cropSunPartialHint': 'من 3 إلى 6 ساعات من الشمس المباشرة يوميًا',
    'cropSunShade': 'ظل في أغلب اليوم',
    'cropSunShadeHint': 'أقل من 3 ساعات من الشمس المباشرة يوميًا',
    'cropWaterQuestion': 'كم مرة ستسقي؟',
    'cropWaterLow': 'قليل',
    'cropWaterLowHint': 'مرة في الأسبوع أو أقل',
    'cropWaterMedium': 'متوسط',
    'cropWaterMediumHint': 'عدة مرات في الأسبوع',
    'cropWaterHigh': 'كثير',
    'cropWaterHighHint': 'يوميًا مع إبقاء التربة رطبة',
    'month1': 'يناير',
    'month2': 'فبراير',
    'month3': 'مارس',
    'month4': 'أبريل',
    'month5': 'مايو',
    'month6': 'يونيو',
    'month7': 'يوليو',
    'month8': 'أغسطس',
    'month9': 'سبتمبر',
    'month10': 'أكتوبر',
    'month11': 'نوفمبر',
    'month12': 'ديسمبر',
    'listJoin': '، ',
    'note_temp_ok': 'الطقس في منطقتك يناسبه طوال الموسم',
    'note_rain_ok': 'أمطار منطقتك تكفي احتياجه من الماء',
    'note_light_ok': 'كمية الشمس في مكانك تناسبه',
    'note_water_ok': 'معدل سقيك يناسب احتياجه من الماء',
    'note_water_more_often': 'يحتاج سقيًا عدة مرات في الأسبوع، أكثر مما تخطط له',
    'note_water_less_often': 'يفضّل التربة الجافة: اترك التربة تجف بين كل سقية وأخرى',
    'note_needs_acidic_soil':
        'تربة منطقتك قلوية أكثر مما يتحمّل: ازرعه في أصيص بتربة زراعية جاهزة، أو أضف الكبريت الزراعي إلى التربة',
    'note_needs_acidic_mix':
        'يحتاج تربة زراعية حمضية مخصصة للنباتات المحبة للحموضة',
    'note_needs_alkaline_soil':
        'يحتاج تربة أقل حموضة من تربتك: أضف الجير الزراعي إلى التربة',
    'note_plant_next_month': 'أفضل وقت لزراعته الشهر القادم، في {month}',
    'note_plant_later': 'أفضل وقت لزراعته في {month}',
    'note_needs_shade':
        'يحتاج تظليلًا في {months}: استخدم قماش تظليل أو انقل الأصيص إلى الداخل',
    'note_needs_cover':
        'يحتاج تغطية في الليالي الباردة في {months}: استخدم غطاء صقيع أو انقل الأصيص إلى الداخل',
    'note_too_cool': 'ينمو ببطء في {months} لأن الجو أبرد مما يفضّل',
    'note_too_hot': 'الجو أحر مما يفضّل في {months}: وفّر له ظلًا وقت العصر',
    'note_too_wet':
        'الأمطار في منطقتك أكثر من حاجته: ازرعه في حوض مرتفع أو أصيص يصرّف الماء',
    'note_too_dry': 'منطقتك جافة، لذلك يحتاج سقيًا منتظمًا',
    'note_needs_watering': 'يحتاج سقيًا بين فترات المطر',
    'note_needs_wet_soil': 'يحتاج تربة مبللة دائمًا: ازرعه في أصيص داخل صحن ماء',
    'note_light_too_strong':
        'الشمس في مكانك أقوى مما يتحمّل: ظلّله، خاصة وقت العصر',
    'cropSwipeHint': 'اسحب للتنقل بين أنواع المحاصيل',
    'tryAgain': 'حاول مرة أخرى',
    'cropShowTips': 'اعرض {n} نصائح أخرى',
    'cropHideTips': 'اعرض نصائح أقل',
    'startupErrorTitle': 'تعذّر الاتصال',
    'startupErrorBody': 'تأكد من اتصالك بالإنترنت وحاول مرة أخرى بعد قليل.',
    'homeGoodMorning': 'صباح الخير،',
    'homeGoodAfternoon': 'مساء الخير،',
    'homeGoodEvening': 'مساء الخير،',
    'homeSlogan1': 'ثمار الغد تبدأ ببذرة اليوم',
    'homeSlogan2': 'ازرع اليوم، وغيّر الغد',
    'homeSlogan3': 'الأشياء الجميلة تحتاج وقتًا لتنمو',
    'streakNotStartedTitle': '0 أيام متتالية',
    'streakNotStartedHint': 'ازرع نبتتك الأولى، وابدأ سلسلتك الآن!',
    'streakActiveTitle': '{n} أيام متتالية',
    'streakActiveTitleOne': 'يوم واحد متتالٍ',
    'streakActiveTitleTwo': 'يومان متتاليان',
    'streakActiveTitleMany': '{n} يومًا متتاليًا',
    'streakActiveHint': 'أحسنت! واصل العناية بنباتاتك للحفاظ على السلسلة.',
    'streakLostTitle': 'انقطعت السلسلة',
    'streakLostHint': 'حافظ على نباتاتك وابدأ السلسلة من جديد.',
    'homeAddPlant': 'أضف نبتة',
    'homeNearMe': 'قريب مني',
    'navHome': 'الرئيسية',
    'navDailyTasks': 'المهام اليومية',
    // Daily Tasks screen
    'dailyTasksSubtitle': 'اعتنِ بنباتاتك اليوم',
    'dailyProgress': 'التقدم اليومي',
    'dailyProgressOf': 'أُنجزت {done} من {total} مهام',
    'todaysTasks': 'مهام اليوم',
    'taskWatering': 'الري',
    'taskFertilizing': 'التسميد',
    'statusCompleted': 'مكتملة',
    'statusOverdue': 'متأخرة',
    'statusUpcoming': 'قادمة',
    'taskMarkDone': 'تحديد كمكتملة',
    // تاريخ اليوم، مثل "الأربعاء، 21 أكتوبر".
    'todayDate': '{weekday}، {day} {month}',
    'weekday1': 'الاثنين',
    'weekday2': 'الثلاثاء',
    'weekday3': 'الأربعاء',
    'weekday4': 'الخميس',
    'weekday5': 'الجمعة',
    'weekday6': 'السبت',
    'weekday7': 'الأحد',
    'monthLong1': 'يناير',
    'monthLong2': 'فبراير',
    'monthLong3': 'مارس',
    'monthLong4': 'أبريل',
    'monthLong5': 'مايو',
    'monthLong6': 'يونيو',
    'monthLong7': 'يوليو',
    'monthLong8': 'أغسطس',
    'monthLong9': 'سبتمبر',
    'monthLong10': 'أكتوبر',
    'monthLong11': 'نوفمبر',
    'monthLong12': 'ديسمبر',
    'navVirtualFarm': "مزرعتك",
    'homeCardRecommended': "توصياتنا لك",
    'homeCardNearMe': "خريطة إثمار",
    'homeCardLeaderboard': 'لوحة الصدارة',
    'homeCardAddPlant': 'ازرع نبتة',
    'homeCardDiagnosis': "افحص نبتتك",
    'navAskThamoor': 'اسأل ثمور',
    'profile': 'الملف الشخصي',
    'editProfile': 'تعديل الملف الشخصي',
    // Profile screen
    'memberSince': 'عضو منذ {date}',
    'statMyPlants': "نباتاتك",
    'statMyRank': "ترتيبك",
    'settingsTitle': 'الإعدادات',
    'settingsLanguage': 'اللغة',
    'aboutEthmar': 'عن إثمار',
    'contactEthmar': "تواصل معنا",
    'chooseLanguage': 'اختر اللغة',
    'languageArabic': 'العربية',
    'languageEnglish': 'English',
    'logOutConfirmTitle': 'تسجيل الخروج؟',
    'logOutConfirmBody': 'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
    // About Ethmar
    'aboutTagline': 'مساعدك الزراعي الشخصي',
    'aboutWhatTitle': 'ما هو إثمار؟',
    'aboutWhatBody':
        'إثمار تطبيق للزراعة المنزلية يتيح للمستخدمين استكشاف المحاصيل المناسبة لمناخ مناطقهم، وتنظيم مهام العناية بالنباتات ومتابعة نموها. ويضم مجموعة من الميزات الذكية والتفاعلية التي تساعد على إدارة تجربة الزراعة المنزلية.',
    'aboutOffersTitle': 'الميزات الرئيسية',
    'aboutCard1Title': 'اختيار المحاصيل والخدمات القريبة',
    'aboutCard1Body':
        'يوفّر إثمار توصيات بالمحاصيل المناسبة وفقًا لمناخ المنطقة، بالإضافة إلى خريطة تفاعلية تساعد المستخدمين على العثور على المشاتل ومتاجر المستلزمات الزراعية والخدمات القريبة.',
    'aboutCard2Title': 'العناية بالنباتات ومتابعتها',
    'aboutCard2Body':
        'يوفّر التطبيق تذكيرات بمهام الري والتسميد، وتنبيهات للتغيرات الجوية التي قد تؤثر على النباتات، وأدوات لمتابعة نموها. كما يتضمن ميزة للكشف عن أمراض النباتات باستخدام الصور، ومساعدًا ذكيًا للإجابة عن الاستفسارات المتعلقة بالزراعة.',
    'aboutCard3Title': 'التجربة الزراعية التفاعلية',
    'aboutCard3Body':
        'يتضمن إثمار مزرعة افتراضية لعرض النباتات ومتابعة نموها، إلى جانب لوحة الصدارة التي تضفي طابعًا تفاعليًا وتنافسيًا على تجربة الزراعة المنزلية، وتشجع المستخدمين على مواصلة العناية بنباتاتهم.',
    'aboutGoalTitle': 'هدفنا',
    'aboutGoalBody':
        'يهدف إثمار إلى تشجيع الزراعة المنزلية وزيادة انتشارها من خلال توفير تجربة متكاملة تجمع الخدمات والميزات التي يحتاجها المستخدم في تطبيق واحد، مما يجعل زراعة النباتات والعناية بها أكثر سهولة وتنظيمًا.',
    // Contact Ethmar

    'contactEmailTitle': "البريد الإلكتروني",
    'contactXTitle': "منصة X",
    'errOpenEmail': 'تعذّر فتح تطبيق البريد، وتم نسخ العنوان.',
    'errOpenLink': 'تعذّر فتح الرابط، وتم نسخه.',
    'takePhoto': 'التقط صورة',
    'chooseFromGallery': 'اختر من المعرض',
    'deletePhoto': 'حذف الصورة',
    'profilePhotoUploaded': 'تم رفع صورة الملف الشخصي.',
    'profilePhotoDeleted': 'تم حذف صورة الملف الشخصي.',
    'errProfilePhotoAuth': 'انتهت جلستك. سجّل الدخول مجددًا ثم حاول مرة أخرى.',
    'errProfilePhotoVerification': 'تحقق من بريدك قبل تغيير صورتك.',
    'errProfilePhotoType':
        'صيغة الصورة غير مدعومة. يُرجى اختيار صورة بصيغة JPEG أو PNG أو WebP.',
    'errProfilePhotoSize':
        'حجم الصورة يتجاوز 5 ميجابايت. يُرجى اختيار صورة أصغر.',
    'errProfilePhotoRateLimit':
        'طلبات صور كثيرة. انتظر دقيقة ثم حاول مرة أخرى.',
    'errProfilePhotoServer': 'خدمة الصور غير متاحة حاليًا. حاول لاحقًا.',
    'errProfilePhotoSave':
        'تغيّرت الصورة، لكن تعذّر تحديث ملفك. حاول مرة أخرى.',
    'errImageRead': 'تعذّر قراءة الصورة. يُرجى المحاولة مرة أخرى.',
    'errCameraOpen': 'تعذّر تشغيل الكاميرا. يُرجى المحاولة مرة أخرى.',
    'errPhotoCapture': 'تعذّر التقاط الصورة. يُرجى المحاولة مرة أخرى.',
    'errPhotoSelect': 'تعذّر اختيار الصورة. يُرجى المحاولة مرة أخرى.',
    'errPhotoUpload': 'تعذّر رفع الصورة. يُرجى المحاولة مرة أخرى.',
    'errPhotoDelete': 'تعذّر حذف الصورة. يُرجى المحاولة مرة أخرى.',
    'cameraAccessTitle': 'السماح بالوصول إلى الكاميرا',
    'cameraAccessBody':
        'لالتقاط صورة للملف الشخصي، فعّل صلاحية الكاميرا لتطبيق إثمار من إعدادات جهازك.',
    'openSettings': 'فتح الإعدادات',
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
    'scanTitle': 'افحص ورقة',
    'scanAccent': 'قرّب لي الورقة المريضة',
    'scanTipsTitle': 'لأفضل نتيجة',
    'scanTipLight': 'إضاءة جيدة',
    'scanTipOneLeaf': 'ورقة وحدة',
    'scanTipStill': 'ثبّت يدك',
    'scanCapture': 'التقط صورة للورقة',
    'scanNoCamera': 'ما قدرنا نفتح الكاميرا. اسمح باستخدام الكاميرا ثم حاول مرة أخرى.',
    'scanAnalysing1': 'نطالع ورقتك…',
    'scanAnalysing2': 'نشيّك على البقع والألوان…',
    'scanAnalysing3': 'نعرف وش تحتاج…',
    'diagEasyToFix': 'علاجها سهل',
    'diagDryLeavesName': 'جفاف الأوراق',
    'diagDryLeavesBody':
        'أطراف الورقة بدأت تجف. غالبًا السبب شمس قوية أو ري قليل.',
    'scanAnother': 'افحص ورقة ثانية',
    'backToHome': 'رجوع للرئيسية',
    'chatTitle': 'إثمار دايم موجود يساعدك',
    'chatGreeting': 'أهلًا {name}، قول لي وش تحتاج.',
    'chatHint': 'اسأل إثمار…',
    'chatSend': 'إرسال',
    'close': 'إغلاق',
    'mapAccent': 'مشاتل ومتاجر زراعية حولك',
    'mapFilterAll': 'الكل',
    'mapFilterNurseries': 'مشاتل',
    'mapFilterStores': 'متاجر زراعية',
    'mapNursery': 'مشتل',
    'mapStore': 'متجر زراعي',
    'mapKm': '{km} كم',
    'mapLocating': 'نحدد موقعك…',
    'mapDeniedTitle': 'نحتاج إذن الموقع',
    'mapDeniedBody':
        'نحتاج الوصول لموقعك (GPS) عشان نلقى الخدمات القريبة منك. اسمح بالوصول للموقع عشان تشوف الخريطة.',
    'mapAllowLocation': 'السماح بالموقع',
    'mapRecenter': 'اعرض موقعي',
    'mapYouAreHere': 'أنت هنا',
    'farmTitle': 'مزرعتي الافتراضية',
    'farmAccent': 'أرضك جاهزة لأول بذرة',
    'farmLand': 'أرض مزرعتك الفاضية',
    'farmZoomIn': 'تكبير',
    'farmZoomOut': 'تصغير',
    'farmResetView': 'إعادة العرض',
    'farmPinchHint': 'قرّب وبعّد بإصبعين',
    'farmAddLand': 'أضف أرض',
    'filterAll': 'الكل',
    'addPlantTitle': 'أضف نبتة',
    'addPlantStep': 'الخطوة {n} من 2',
    'addPlantChoose': 'اختر محصولك',
    'addPlantDetails': 'الاسم والمواعيد',
    'addPlantChange': 'تغيير',
    'addPlantNameLabel': 'سمّ نبتتك',
    'addPlantNameHint': 'مثلًا: طماطم البلكونة',
    'errPlantNameRequired': 'اكتب اسم لنبتتك',
    'errPlantNameLong': 'خلّ الاسم أقل من ٣٠ حرف',
    'addPlantButton': 'أضف النبتة',
    'addPlantLaterHint': 'المواعيد اختيارية، تقدر تضبطها بعدين.',
    'schedIrrigation': 'جدول الري',
    'schedFertilization': 'جدول التسميد',
    'schedRepetition': 'التكرار',
    'schedAlarmTime': 'وقت التنبيه',
    'schedLessOften': 'أقل تكرار',
    'schedMoreOften': 'أكثر تكرار',
    'repeatEveryDay': 'كل يوم',
    'repeatEvery2Days': 'كل يومين',
    'repeatEvery3Days': 'كل ٣ أيام',
    'repeatEveryWeek': 'كل أسبوع',
    'repeatEvery2Weeks': 'كل أسبوعين',
    'repeatEveryMonth': 'كل شهر',
    'summaryTitle': 'جاهز تزرعها؟',
    'summaryIrrigation': 'الري',
    'summaryFertilization': 'التسميد',
    'summaryNotSet': 'ما تحدد بعد',
    'summaryAt': '{repeat} الساعة {time}',
    'confirm': 'تأكيد',
    'plantAdded': 'تمت إضافة {name} لمزرعتك',
    'farmLandFull':
        'أرضك امتلأت! أضف أرض جديدة في مزرعتك الافتراضية عشان تكمل الزراعة.',
    'myPlants': 'نباتاتي',
    'myPlantsAccent': 'كل اللي يكبر في مزرعتك',
    'myPlantsEmpty': 'ما عندك نباتات للحين',
    'myPlantsEmptyBody': 'أضف أول نبتة وبتطلع لك هنا.',
    'plantedToday': 'انزرعت اليوم',
    'plantDays': '{n} يوم',
    'plantDayOne': 'يوم واحد',
    'daysSincePlanting': 'أيام منذ الزراعة',
    'stagesTitle': 'مراحل النمو',
    'stagesEmpty': 'ما فيه صور للحين. ارفع صورة كل فترة عشان تشوف نبتتك وهي تكبر.',
    'uploadPicture': 'ارفع صورة',
    'notesTitle': 'تضيف ملاحظة؟',
    'notesLabel': 'ملاحظات (اختياري)',
    'notesHint': 'مثلًا: طلعت أول زهرة',
    'pictureAdded': 'تمت إضافة الصورة لمراحل النمو',
    'careSchedule': 'جدول العناية',
    'edit': 'تعديل',
    'scheduleNext': 'القادم: {when}',
    'today': 'اليوم',
    'tomorrow': 'بكرة',
    'editPlantTitle': 'تعديل النبتة',
    'plantUpdated': 'تم تحديث النبتة',
    'leaderboardTitle': 'المتصدرون',
    'leaderboardAccent': 'مين يزرع أكثر؟',
    'rankFirst': 'أنت الأول! مزرعتك هي الأكبر.',
    'rankTopTen': 'ترتيبك #{rank} وأنت من أفضل ١٠! كمّل زراعة.',
    'rankKeepGoing': 'ترتيبك #{rank} وعندك {plants}. كمّل عشان توصل لأفضل ١٠!',
    'plantsCount': '{n} نبتة',
    'plantsCountOne': 'نبتة وحدة',
    'you': 'أنت',
    'rankLabel': 'المركز {rank}',
    'rankToTopTen': 'باقي {plants}',
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
  String get forgotPassword => t('forgotPassword');
  String get loginButton => t('loginButton');
  String get newHere => t('newHere');
  String get createAccountLink => t('createAccountLink');
  String get errUsernameRequired => t('errUsernameRequired');
  String get errUsernameTaken => t('errUsernameTaken');
  String get errUsernameCheckFailed => t('errUsernameCheckFailed');
  String get errEmailRequired => t('errEmailRequired');
  String get errEmailInvalid => t('errEmailInvalid');
  String get errPasswordRequired => t('errPasswordRequired');
  String get errPasswordLength => t('errPasswordLength');
  String get errPasswordUpper => t('errPasswordUpper');
  String get errPasswordDigit => t('errPasswordDigit');
  String get errPasswordSpecial => t('errPasswordSpecial');

  /// Every password rule (used when the server says the password is weak).
  String get errPasswordWeak => passwordNeeds([
        errPasswordLength,
        errPasswordUpper,
        errPasswordDigit,
        errPasswordSpecial,
      ]);

  /// "Your password needs a number", or a bullet list when several rules
  /// are missing.
  String passwordNeeds(List<String> missing) => missing.length == 1
      ? '${t('errPasswordNeeds')} ${missing.single}'
      : '${t('errPasswordNeeds')}:\n${missing.map((m) => '• $m').join('\n')}';
  String get showPassword => t('showPassword');
  String get hidePassword => t('hidePassword');
  String get back => t('back');
  String get accountCreated => t('accountCreated');
  String get resetTitle => t('resetTitle');
  String get sendResetLink => t('sendResetLink');
  String get backToLogin => t('backToLogin');
  String get resetLinkSent => t('resetLinkSent');
  String get emailVerified => t('emailVerified');
  String get verifyDialogTitle => t('verifyDialogTitle');
  String verifyDialogBody(String email) =>
      t('verifyDialogBody').replaceAll('{email}', email);
  String get verifyDialogWaiting => t('verifyDialogWaiting');
  String get resendEmail => t('resendEmail');
  String get verificationResent => t('verificationResent');
  String get emailNotVerifiedTitle => t('emailNotVerifiedTitle');
  String verificationRecoveryBody(String email) =>
      t('verificationRecoveryBody').replaceAll('{email}', email);
  String get checkVerification => t('checkVerification');
  String get verificationStillPending => t('verificationStillPending');
  String get errSignUpUnfinished => t('errSignUpUnfinished');
  String get errSignUpUnfinishedLogIn => t('errSignUpUnfinishedLogIn');
  String get errEmailAlreadyInUse => t('errEmailAlreadyInUse');
  String get errTooManyRequests => t('errTooManyRequests');
  String get errNetwork => t('errNetwork');
  String get errAuthGeneral => t('errAuthGeneral');
  String get errAuthSessionMismatch => t('errAuthSessionMismatch');
  String get errInvalidCredentials => t('errInvalidCredentials');
  String get errProfileCreate => t('errProfileCreate');
  String get errProfileConflict => t('errProfileConflict');
  String get errProfileLoad => t('errProfileLoad');
  String get errLogout => t('errLogout');
  String get homeFriend => t('homeFriend');
  String get logOut => t('logOut');
  String get cropTitle => t('cropTitle');
  String get cropAccent => t('cropAccent');
  String get cropCatHerb => t('cropCatHerb');
  String get cropCatLegume => t('cropCatLegume');
  String get cropCatRoot => t('cropCatRoot');
  String get cropCatVegetable => t('cropCatVegetable');
  String get cropCatFruit => t('cropCatFruit');
  List<String> get cropLoadingSteps => [
    t('cropLoading1'),
    t('cropLoading2'),
    t('cropLoading3'),
  ];
  String get cropTempRange => t('cropTempRange');
  String get cropWaterNeed => t('cropWaterNeed');
  String get cropBestTime => t('cropBestTime');
  String get cropHarvest => t('cropHarvest');
  String get cropGrowsTo => t('cropGrowsTo');
  String get cropDays => t('cropDays');
  String get cropMeters => t('cropMeters');
  String get cropNoCrops => t('cropNoCrops');
  String get cropError => t('cropError');
  String get cropErrorSignIn => t('cropErrorSignIn');
  String get cropErrorClimate => t('cropErrorClimate');
  String get cropErrorOffline => t('cropErrorOffline');
  String get cropMoreFailed => t('cropMoreFailed');
  String get cropLocationDenied => t('cropLocationDenied');
  String get cropLocationBlocked => t('cropLocationBlocked');
  String get cropLocationOff => t('cropLocationOff');
  String get cropLocationUnavailable => t('cropLocationUnavailable');
  String get cropOpenSettings => t('cropOpenSettings');
  String get cropPlantingQuestion => t('cropPlantingQuestion');
  String get cropSetupWhy => t('cropSetupWhy');
  String get cropNoCropsLowSun => t('cropNoCropsLowSun');
  String get cropFewInShade => t('cropFewInShade');
  String get cropChangeAnswers => t('cropChangeAnswers');
  String cropSetupStep(int n) => t('cropSetupStep').replaceAll('{n}', '$n');
  String get cropPlantingPot => t('cropPlantingPot');
  String get cropPlantingPotHint => t('cropPlantingPotHint');
  String get cropPlantingGround => t('cropPlantingGround');
  String get cropPlantingGroundHint => t('cropPlantingGroundHint');
  String get cropSunQuestion => t('cropSunQuestion');
  String get cropSunFull => t('cropSunFull');
  String get cropSunFullHint => t('cropSunFullHint');
  String get cropSunPartial => t('cropSunPartial');
  String get cropSunPartialHint => t('cropSunPartialHint');
  String get cropSunShade => t('cropSunShade');
  String get cropSunShadeHint => t('cropSunShadeHint');
  String get cropWaterQuestion => t('cropWaterQuestion');
  String get cropWaterLow => t('cropWaterLow');
  String get cropWaterLowHint => t('cropWaterLowHint');
  String get cropWaterMedium => t('cropWaterMedium');
  String get cropWaterMediumHint => t('cropWaterMediumHint');
  String get cropWaterHigh => t('cropWaterHigh');
  String get cropWaterHighHint => t('cropWaterHighHint');

  /// Month 1-12 by name, e.g. "Oct" / "أكتوبر".
  String monthName(int month) => t('month$month');

  /// Months as ranges, e.g. [10, 11, 12, 1, 2] -> "Oct–Feb"; a full year
  /// gives "All year". The year wraps, so Dec and Jan count as next to each
  /// other.
  String monthRanges(List<int> months) {
    final set = months.where((m) => m >= 1 && m <= 12).toSet();
    if (set.length == 12) return t('cropAllYear');
    if (set.isEmpty) return '';
    // Start each run at a month whose previous month is not in the set.
    final runs = <String>[];
    for (var m = 1; m <= 12; m++) {
      final previous = m == 1 ? 12 : m - 1;
      if (!set.contains(m) || set.contains(previous)) continue;
      var end = m;
      while (set.contains(end % 12 + 1)) {
        end = end % 12 + 1;
      }
      runs.add(end == m ? monthName(m) : '${monthName(m)}–${monthName(end)}');
    }
    return runs.join(t('listJoin'));
  }

  String cropBand(MatchBand band) => t('cropBand_${band.name}');

  /// Water need such as ["low", "medium"] -> "Low–Medium".
  String cropWater(List<String> levels) {
    final known = [
      for (final level in const ['low', 'medium', 'high'])
        if (levels.contains(level)) t('cropWater_$level'),
    ];
    if (known.isEmpty) return '';
    return known.length == 1 ? known.first : '${known.first}–${known.last}';
  }

  /// The sentence for a reason or warning from the model. A code the app
  /// doesn't know yet falls back to the model's English text.
  String cropNote(ModelNote note) {
    final key = 'note_${note.code}';
    if (!_map.containsKey(key)) return note.text;
    final month = note.month;
    return t(key)
        .replaceAll('{month}', month == null ? '' : monthName(month))
        .replaceAll('{months}', monthRanges(note.months));
  }

  String get cropSwipeHint => t('cropSwipeHint');
  String get tryAgain => t('tryAgain');
  String cropShowTips(int n) => t('cropShowTips').replaceAll('{n}', '$n');
  String get cropHideTips => t('cropHideTips');
  String get startupErrorTitle => t('startupErrorTitle');
  String get startupErrorBody => t('startupErrorBody');
  String get homeGoodMorning => t('homeGoodMorning');
  String get homeGoodAfternoon => t('homeGoodAfternoon');
  String get homeGoodEvening => t('homeGoodEvening');
  /// Home slogan by its stable index (0, 1 or 2).
  String homeSlogan(int i) => t('homeSlogan${i + 1}');
  String get streakNotStartedTitle => t('streakNotStartedTitle');
  String get streakNotStartedHint => t('streakNotStartedHint');
  String get streakActiveHint => t('streakActiveHint');
  String get streakLostTitle => t('streakLostTitle');
  String get streakLostHint => t('streakLostHint');

  /// "{n} day streak", with the correct Arabic number form:
  /// 1 → يوم واحد, 2 → يومان, 3–10 → أيام, 11+ → يومًا.
  String streakActiveTitle(int n) => switch (n) {
        1 => t('streakActiveTitleOne'),
        2 => t('streakActiveTitleTwo'),
        >= 3 && <= 10 => t('streakActiveTitle').replaceAll('{n}', '$n'),
        _ => t('streakActiveTitleMany').replaceAll('{n}', '$n'),
      };
  String get homeAddPlant => t('homeAddPlant');
  String get homeNearMe => t('homeNearMe');
  String get navHome => t('navHome');
  String get navDailyTasks => t('navDailyTasks');
  String get dailyTasksSubtitle => t('dailyTasksSubtitle');
  String get dailyProgress => t('dailyProgress');
  String dailyProgressOf(int done, int total) => t('dailyProgressOf')
      .replaceAll('{done}', '$done')
      .replaceAll('{total}', '$total');
  String get todaysTasks => t('todaysTasks');
  String get taskWatering => t('taskWatering');
  String get taskFertilizing => t('taskFertilizing');
  String get statusCompleted => t('statusCompleted');
  String get statusOverdue => t('statusOverdue');
  String get statusUpcoming => t('statusUpcoming');
  String get taskMarkDone => t('taskMarkDone');

  /// Today's date without the year, e.g. "Wednesday, October 21" /
  /// "الأربعاء، 21 أكتوبر".
  String todayDate(DateTime d) => t('todayDate')
      .replaceAll('{weekday}', t('weekday${d.weekday}'))
      .replaceAll('{month}', t('monthLong${d.month}'))
      .replaceAll('{day}', '${d.day}');
  String get navVirtualFarm => t('navVirtualFarm');
  String get homeCardRecommended => t('homeCardRecommended');
  String get homeCardNearMe => t('homeCardNearMe');
  String get homeCardLeaderboard => t('homeCardLeaderboard');
  String get homeCardAddPlant => t('homeCardAddPlant');
  String get homeCardDiagnosis => t('homeCardDiagnosis');
  String get navAskThamoor => t('navAskThamoor');
  String get profile => t('profile');
  String get editProfile => t('editProfile');
  String memberSince(String date) => t('memberSince').replaceAll('{date}', date);
  String get statMyPlants => t('statMyPlants');
  String get statMyRank => t('statMyRank');
  String get settingsTitle => t('settingsTitle');
  String get settingsLanguage => t('settingsLanguage');
  String get aboutEthmar => t('aboutEthmar');
  String get contactEthmar => t('contactEthmar');
  String get chooseLanguage => t('chooseLanguage');
  String get languageArabic => t('languageArabic');
  String get languageEnglish => t('languageEnglish');
  String get logOutConfirmTitle => t('logOutConfirmTitle');
  String get logOutConfirmBody => t('logOutConfirmBody');
  String get aboutTagline => t('aboutTagline');
  String get aboutWhatTitle => t('aboutWhatTitle');
  String get aboutWhatBody => t('aboutWhatBody');
  String get aboutOffersTitle => t('aboutOffersTitle');
  String get aboutCard1Title => t('aboutCard1Title');
  String get aboutCard1Body => t('aboutCard1Body');
  String get aboutCard2Title => t('aboutCard2Title');
  String get aboutCard2Body => t('aboutCard2Body');
  String get aboutCard3Title => t('aboutCard3Title');
  String get aboutCard3Body => t('aboutCard3Body');
  String get aboutGoalTitle => t('aboutGoalTitle');
  String get aboutGoalBody => t('aboutGoalBody');
  String get contactEmailTitle => t('contactEmailTitle');
  String get contactXTitle => t('contactXTitle');
  String get errOpenEmail => t('errOpenEmail');
  String get errOpenLink => t('errOpenLink');
  String get takePhoto => t('takePhoto');
  String get chooseFromGallery => t('chooseFromGallery');
  String get deletePhoto => t('deletePhoto');
  String get profilePhotoUploaded => t('profilePhotoUploaded');
  String get profilePhotoDeleted => t('profilePhotoDeleted');
  String get errProfilePhotoAuth => t('errProfilePhotoAuth');
  String get errProfilePhotoVerification => t('errProfilePhotoVerification');
  String get errProfilePhotoType => t('errProfilePhotoType');
  String get errProfilePhotoSize => t('errProfilePhotoSize');
  String get errProfilePhotoRateLimit => t('errProfilePhotoRateLimit');
  String get errProfilePhotoServer => t('errProfilePhotoServer');
  String get errProfilePhotoSave => t('errProfilePhotoSave');
  String get errImageRead => t('errImageRead');
  String get errCameraOpen => t('errCameraOpen');
  String get errPhotoCapture => t('errPhotoCapture');
  String get errPhotoSelect => t('errPhotoSelect');
  String get errPhotoUpload => t('errPhotoUpload');
  String get errPhotoDelete => t('errPhotoDelete');
  String get cameraAccessTitle => t('cameraAccessTitle');
  String get cameraAccessBody => t('cameraAccessBody');
  String get openSettings => t('openSettings');
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
  String get scanTitle => t('scanTitle');
  String get scanAccent => t('scanAccent');
  String get scanTipsTitle => t('scanTipsTitle');
  String get scanTipLight => t('scanTipLight');
  String get scanTipOneLeaf => t('scanTipOneLeaf');
  String get scanTipStill => t('scanTipStill');
  String get scanCapture => t('scanCapture');
  String get scanNoCamera => t('scanNoCamera');
  List<String> get scanAnalysingSteps => [
    t('scanAnalysing1'),
    t('scanAnalysing2'),
    t('scanAnalysing3'),
  ];
  String get diagEasyToFix => t('diagEasyToFix');
  String get diagDryLeavesName => t('diagDryLeavesName');
  String get diagDryLeavesBody => t('diagDryLeavesBody');
  String get scanAnother => t('scanAnother');
  String get backToHome => t('backToHome');
  String get chatTitle => t('chatTitle');
  String chatGreeting(String name) =>
      t('chatGreeting').replaceAll('{name}', name);
  String get chatHint => t('chatHint');
  String get chatSend => t('chatSend');
  String get close => t('close');
  String get mapAccent => t('mapAccent');
  String get mapFilterAll => t('mapFilterAll');
  String get mapFilterNurseries => t('mapFilterNurseries');
  String get mapFilterStores => t('mapFilterStores');
  String get mapNursery => t('mapNursery');
  String get mapStore => t('mapStore');
  String mapKm(String km) => t('mapKm').replaceAll('{km}', km);
  String get mapLocating => t('mapLocating');
  String get mapDeniedTitle => t('mapDeniedTitle');
  String get mapDeniedBody => t('mapDeniedBody');
  String get mapAllowLocation => t('mapAllowLocation');
  String get mapRecenter => t('mapRecenter');
  String get mapYouAreHere => t('mapYouAreHere');
  String get farmTitle => t('farmTitle');
  String get farmAccent => t('farmAccent');
  String get farmLand => t('farmLand');
  String get farmZoomIn => t('farmZoomIn');
  String get farmZoomOut => t('farmZoomOut');
  String get farmResetView => t('farmResetView');
  String get farmPinchHint => t('farmPinchHint');
  String get farmAddLand => t('farmAddLand');
  String get filterAll => t('filterAll');
  String get addPlantTitle => t('addPlantTitle');
  String addPlantStep(int n) => t('addPlantStep').replaceAll('{n}', '$n');
  String get addPlantChoose => t('addPlantChoose');
  String get addPlantDetails => t('addPlantDetails');
  String get addPlantChange => t('addPlantChange');
  String get addPlantNameLabel => t('addPlantNameLabel');
  String get addPlantNameHint => t('addPlantNameHint');
  String get errPlantNameRequired => t('errPlantNameRequired');
  String get errPlantNameLong => t('errPlantNameLong');
  String get addPlantButton => t('addPlantButton');
  String get addPlantLaterHint => t('addPlantLaterHint');
  String get schedIrrigation => t('schedIrrigation');
  String get schedFertilization => t('schedFertilization');
  String get schedRepetition => t('schedRepetition');
  String get schedAlarmTime => t('schedAlarmTime');
  String get schedLessOften => t('schedLessOften');
  String get schedMoreOften => t('schedMoreOften');
  String get repeatEveryDay => t('repeatEveryDay');
  String get repeatEvery2Days => t('repeatEvery2Days');
  String get repeatEvery3Days => t('repeatEvery3Days');
  String get repeatEveryWeek => t('repeatEveryWeek');
  String get repeatEvery2Weeks => t('repeatEvery2Weeks');
  String get repeatEveryMonth => t('repeatEveryMonth');
  String get summaryTitle => t('summaryTitle');
  String get summaryIrrigation => t('summaryIrrigation');
  String get summaryFertilization => t('summaryFertilization');
  String get summaryNotSet => t('summaryNotSet');
  String summaryAt(String repeat, String time) =>
      t('summaryAt').replaceAll('{repeat}', repeat).replaceAll('{time}', time);
  String get confirm => t('confirm');
  String plantAdded(String name) => t('plantAdded').replaceAll('{name}', name);
  String get farmLandFull => t('farmLandFull');
  String get myPlants => t('myPlants');
  String get myPlantsAccent => t('myPlantsAccent');
  String get myPlantsEmpty => t('myPlantsEmpty');
  String get myPlantsEmptyBody => t('myPlantsEmptyBody');

  /// "Planted today", "1 day", "24 days".
  String plantAge(int days) => switch (days) {
    0 => t('plantedToday'),
    1 => t('plantDayOne'),
    _ => t('plantDays').replaceAll('{n}', '$days'),
  };
  String get daysSincePlanting => t('daysSincePlanting');
  String get stagesTitle => t('stagesTitle');
  String get stagesEmpty => t('stagesEmpty');
  String get uploadPicture => t('uploadPicture');
  String get notesTitle => t('notesTitle');
  String get notesLabel => t('notesLabel');
  String get notesHint => t('notesHint');
  String get pictureAdded => t('pictureAdded');
  String get careSchedule => t('careSchedule');
  String get edit => t('edit');
  String scheduleNext(String when) =>
      t('scheduleNext').replaceAll('{when}', when);
  String get today => t('today');
  String get tomorrow => t('tomorrow');
  String get editPlantTitle => t('editPlantTitle');
  String get plantUpdated => t('plantUpdated');
  String get leaderboardTitle => t('leaderboardTitle');
  String get leaderboardAccent => t('leaderboardAccent');

  /// The line under the header, depending on where the user ranks.
  String rankMessage(int rank, int plants) => rank == 1
      ? t('rankFirst')
      : rank <= 10
      ? t('rankTopTen').replaceAll('{rank}', '$rank')
      : t('rankKeepGoing')
            .replaceAll('{rank}', '$rank')
            .replaceAll('{plants}', plantsCount(plants));

  /// "1 plant", "12 plants".
  String plantsCount(int n) => n == 1
      ? t('plantsCountOne')
      : t('plantsCount').replaceAll('{n}', '$n');
  String get you => t('you');
  String rankLabel(int rank) => t('rankLabel').replaceAll('{rank}', '$rank');
  String rankToTopTen(int plants) =>
      t('rankToTopTen').replaceAll('{plants}', plantsCount(plants));
}
