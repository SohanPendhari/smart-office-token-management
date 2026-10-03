import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../utils/constants.dart';
import '../visitor/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.sidebar, AppColors.accent],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.apartment, size: 76, color: Colors.white),
              SizedBox(height: 18),
              Text('SMART OFFICE',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 4)),
              SizedBox(height: 8),
              Text(AppConfig.tagline, style: TextStyle(color: Colors.white70, fontSize: 16)),
              SizedBox(height: 44),
              SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
            ],
          ),
        ),
      ),
    );
  }
}
