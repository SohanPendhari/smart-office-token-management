import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// White rounded surface with a hairline border and a soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.borderColor,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, required this.background, this.icon});

  final String text;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

/// "Open" / "Paused" pill for a department.
class DeptStatusPill extends StatelessWidget {
  const DeptStatusPill({super.key, required this.paused});
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return paused
        ? Pill('Paused', color: AppColors.paused, background: statusBackground('PAUSED'), icon: Icons.pause_circle)
        : Pill('Open', color: AppColors.serving, background: statusBackground('SERVING'), icon: Icons.check_circle);
  }
}

class DepartmentBadge extends StatelessWidget {
  const DepartmentBadge({super.key, required this.code, this.size = 44});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: departmentTint(code), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(departmentIcon(code), color: departmentColor(code), size: size * 0.55),
    );
  }
}

/// Small label + big value.
class Metric extends StatelessWidget {
  const Metric({super.key, required this.label, required this.value, this.color = AppColors.textDark, this.large = false});

  final String label;
  final String value;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: large ? 32 : 22, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Coloured notice box with an icon.
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.text, required this.color, required this.background, required this.icon});

  final String text;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15))),
        ],
      ),
    );
  }
}
