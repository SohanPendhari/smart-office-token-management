import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'providers/providers.dart';
import 'screens/splash/splash_screen.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const SmartOfficeApp(),
  ));
}

class SmartOfficeApp extends StatelessWidget {
  const SmartOfficeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return MaterialApp(
      title: '${AppConfig.appName} - ${AppConfig.tagline}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        dividerColor: AppColors.border,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.accent, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: const BorderSide(color: AppColors.border),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
