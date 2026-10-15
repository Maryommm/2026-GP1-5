import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'l10n/locale_controller.dart';
import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase before building the app.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configure the system status and navigation bars.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const EthmarApp());
}

class EthmarApp extends StatelessWidget {
  const EthmarApp({super.key});

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

        // Start with the splash screen to restore the user session.
        home: const SplashScreen(),
      ),
    );
  }
}