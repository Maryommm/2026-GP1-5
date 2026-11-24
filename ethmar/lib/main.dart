import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'l10n/locale_controller.dart';
import 'screens/splash_screen.dart';
import 'screens/startup_error_screen.dart';
import 'services/care_notifications.dart';
import 'services/farm_store.dart';
import 'theme/app_theme.dart';
import 'theme/system_bars.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and the services that depend on it.
  final firebaseReady = await startFirebaseServices();

  // Open the app in the language the user chose last time.
  await loadSavedLocale();

  // Configure the system status and navigation bars.
  SystemChrome.setSystemUIOverlayStyle(ethmarSystemBars);

  runApp(EthmarApp(firebaseReady: firebaseReady));
}

/// Starts Firebase, then follows the signed-in user's plants and lands and
/// keeps their care reminders scheduled. Used at launch and by the startup
/// error screen's retry, so a successful retry starts the same services.
/// Notifications are awaited so a tap that opened the app is known before
/// the first screen.
Future<bool> startFirebaseServices() async {
  if (!await initFirebase()) return false;
  FarmStore.start();
  await CareNotifications.init();
  return true;
}

/// Starts Firebase and reports whether it worked. The error itself is
/// swallowed on purpose so no configuration details are logged or shown.
Future<bool> initFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return true;
  } catch (_) {
    return false;
  }
}

class EthmarApp extends StatelessWidget {
  const EthmarApp({super.key, this.firebaseReady = true});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    // Rebuild the app when the selected language changes.
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) => MaterialApp(
        title: 'Ethmar',
        debugShowCheckedModeBanner: false,
        theme: buildEthmarTheme(),
        locale: locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        // The usual bars on every page. A page that asks for others (Virtual
        // Farm at night) gets them only while it's on screen.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: ethmarSystemBars,
          child: child!,
        ),

        // Start with the splash screen to restore the user session, or a
        // generic error screen if Firebase could not start.
        home: firebaseReady
            ? const SplashScreen()
            : const StartupErrorScreen(retry: startFirebaseServices),
      ),
    );
  }
}