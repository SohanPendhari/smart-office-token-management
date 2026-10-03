import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard.dart';
import '../../providers/providers.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/statistics_card.dart';

/// Dashboard body (shown inside the staff shell).
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key, required this.onOpenDepartment});

  final void Function(int departmentId) onOpenDepartment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(dashboardProvider);

    return AsyncView<Dashboard>(
      value: value,
      onRetry: () => ref.invalidate(dashboardProvider),
      builder: (d) => ScrollPage(
        maxWidth: 1200,
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveGrid(
              minItemWidth: 220,
              children: [
                StatisticsCard(label: 'Waiting', value: '${d.waiting}', color: AppColors.waiting, icon: Icons.hourglass_top),
                StatisticsCard(label: 'Currently serving', value: '${d.serving}', color: AppColors.serving, icon: Icons.support_agent),
                StatisticsCard(label: 'Completed today', value: '${d.completed}', color: AppColors.accent, icon: Icons.task_alt),
                StatisticsCard(label: 'No-shows today', value: '${d.noShows}', color: AppColors.cancelled, icon: Icons.person_off),
                StatisticsCard(
                    label: 'Avg waiting time', value: formatMinutes(d.averageWaitingMinutes), color: AppColors.priority, icon: Icons.schedule),
                StatisticsCard(
                    label: 'Avg service time', value: formatMinutes(d.averageServiceMinutes), color: AppColors.paused, icon: Icons.timer),
              ],
            ),
            const SizedBox(height: 32),
            const SectionTitle('Departments'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < d.departments.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _DeptRow(dep: d.departments[i], onOpen: () => onOpenDepartment(d.departments[i].id)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeptRow extends StatelessWidget {
  const _DeptRow({required this.dep, required this.onOpen});

  final DepartmentSummary dep;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final wide = isTablet(context);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            DepartmentBadge(code: dep.code, size: 44),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dep.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  DeptStatusPill(paused: dep.isPaused),
                ],
              ),
            ),
            if (wide) ...[
              SizedBox(width: 110, child: Metric(label: 'Waiting', value: '${dep.waiting}')),
              SizedBox(width: 110, child: Metric(label: 'Serving', value: '${dep.serving}')),
              TextButton(onPressed: onOpen, child: const Text('Open queue')),
            ] else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${dep.waiting} waiting', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${dep.serving} serving', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
