import 'package:flutter/material.dart';

import '../models/department.dart';
import '../utils/constants.dart';
import 'app_card.dart';

class DepartmentCard extends StatelessWidget {
  const DepartmentCard({super.key, required this.department, required this.onTap});

  final Department department;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = department;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DepartmentBadge(code: d.code, size: 48),
              const Spacer(),
              DeptStatusPill(paused: d.isPaused),
            ],
          ),
          const SizedBox(height: 16),
          Text(d.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 6),
          Text(
            d.isPaused ? 'New tokens unavailable' : '${d.waiting} waiting  •  ${formatWait(d.estimatedWaitSeconds)}',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(d.isPaused ? 'View status' : 'Get a token',
                  style: TextStyle(color: departmentColor(d.code), fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, size: 16, color: departmentColor(d.code)),
            ],
          ),
        ],
      ),
    );
  }
}
