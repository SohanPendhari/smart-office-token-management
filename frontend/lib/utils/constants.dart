import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color accent = Color(0xFF2563EB);
  static const Color sidebar = Color(0xFF0F1F4B);
  static const Color background = Color(0xFFF5F7FB);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  static const Color waiting = Color(0xFFB45309);
  static const Color serving = Color(0xFF15803D);
  static const Color completed = Color(0xFF475569);
  static const Color cancelled = Color(0xFFB91C1C);
  static const Color paused = Color(0xFF6D28D9);
  static const Color priority = Color(0xFFD97706);
}

IconData departmentIcon(String code) {
  switch (code) {
    case 'IT':
      return Icons.computer;
    case 'HR':
      return Icons.groups;
    case 'ACC':
      return Icons.account_balance_wallet;
    case 'ADM':
      return Icons.apartment;
    default:
      return Icons.business_center;
  }
}

Color departmentColor(String code) {
  switch (code) {
    case 'IT':
      return const Color(0xFF2563EB);
    case 'HR':
      return const Color(0xFF7C3AED);
    case 'ACC':
      return const Color(0xFF059669);
    case 'ADM':
      return const Color(0xFFEA580C);
    default:
      return AppColors.textMuted;
  }
}

Color departmentTint(String code) {
  switch (code) {
    case 'IT':
      return const Color(0xFFDBEAFE);
    case 'HR':
      return const Color(0xFFEDE9FE);
    case 'ACC':
      return const Color(0xFFD1FAE5);
    case 'ADM':
      return const Color(0xFFFFEDD5);
    default:
      return const Color(0xFFE2E8F0);
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'WAITING':
      return AppColors.waiting;
    case 'SERVING':
      return AppColors.serving;
    case 'COMPLETED':
      return AppColors.completed;
    case 'CANCELLED':
      return AppColors.cancelled;
    case 'PAUSED':
      return AppColors.paused;
    default:
      return AppColors.completed;
  }
}

/// Light tinted background that goes with [statusColor].
Color statusBackground(String status) {
  switch (status) {
    case 'WAITING':
      return const Color(0xFFFEF3C7);
    case 'SERVING':
      return const Color(0xFFDCFCE7);
    case 'CANCELLED':
      return const Color(0xFFFEE2E2);
    case 'PAUSED':
      return const Color(0xFFEDE9FE);
    default:
      return const Color(0xFFE2E8F0);
  }
}

/// 1500 -> "~ 25 min", 0 -> "No wait", 30 -> "< 1 min".
String formatWait(int seconds) {
  if (seconds <= 0) return 'No wait';
  if (seconds < 60) return '< 1 min';
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '~ $minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '~ $h h' : '~ $h h $m min';
}

String formatMinutes(double minutes) {
  if (minutes <= 0) return '0 min';
  final rounded = minutes == minutes.roundToDouble() ? minutes.toInt().toString() : minutes.toStringAsFixed(1);
  return '$rounded min';
}
