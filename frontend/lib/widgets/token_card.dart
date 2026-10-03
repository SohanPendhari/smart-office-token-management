import 'package:flutter/material.dart';

import '../models/token.dart';
import '../utils/constants.dart';
import 'app_card.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) =>
      Pill(status, color: statusColor(status), background: statusBackground(status));
}

/// The big "YOUR TOKEN" card.
class TokenCard extends StatelessWidget {
  const TokenCard({super.key, required this.token});
  final Token token;

  @override
  Widget build(BuildContext context) {
    final waiting = token.isWaiting;
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Text('YOUR TOKEN',
              style: TextStyle(letterSpacing: 3, color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Text(token.tokenNumber,
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: AppColors.primary, height: 1.1)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DepartmentBadge(code: token.departmentCode, size: 32),
              const SizedBox(width: 10),
              Text(token.departmentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          if (token.priority) ...[
            const SizedBox(height: 12),
            Pill('Priority', color: AppColors.priority, background: const Color(0xFFFEF3C7), icon: Icons.star),
          ],
          const Padding(padding: EdgeInsets.symmetric(vertical: 22), child: Divider(height: 1)),
          Row(
            children: [
              Expanded(child: Center(child: Metric(label: 'Queue position', value: waiting ? '${token.queuePosition}' : '—'))),
              Container(width: 1, height: 44, color: AppColors.border),
              Expanded(
                  child: Center(
                      child: Metric(label: 'Estimated wait', value: waiting ? formatWait(token.estimatedWaitSeconds) : '—'))),
            ],
          ),
          const SizedBox(height: 22),
          StatusChip(token.status),
        ],
      ),
    );
  }
}
