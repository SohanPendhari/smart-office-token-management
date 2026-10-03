import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/department.dart';
import '../../providers/providers.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/department_card.dart';
import '../../widgets/public_app_bar.dart';
import 'department_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(departmentsProvider);

    return Scaffold(
      appBar: const PublicAppBar(),
      body: AsyncView<List<Department>>(
        value: departments,
        onRetry: () => ref.invalidate(departmentsProvider),
        builder: (list) {
          final waiting = list.fold<int>(0, (sum, d) => sum + d.waiting);
          final wide = isTablet(context);
          return ScrollPage(
            onRefresh: () async => ref.invalidate(departmentsProvider),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Hero(wide: wide, waiting: waiting, departments: list.length),
                const SizedBox(height: 32),
                const SectionTitle('Select a service'),
                ResponsiveGrid(
                  minItemWidth: 240,
                  children: [
                    for (final d in list)
                      DepartmentCard(
                        department: d,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => DepartmentScreen(departmentId: d.id))),
                      ),
                  ],
                ),
                const SizedBox(height: 36),
                const SectionTitle('How it works'),
                const ResponsiveGrid(
                  minItemWidth: 260,
                  children: [
                    _Step(icon: Icons.touch_app, title: '1. Choose a service', text: 'Pick the department you need.'),
                    _Step(
                        icon: Icons.confirmation_number,
                        title: '2. Get your token',
                        text: 'Enter your name and mobile number to receive a token such as IT-021.'),
                    _Step(
                        icon: Icons.notifications_active,
                        title: '3. Wait and get called',
                        text: 'Watch your position and estimated wait update live until staff call you.'),
                  ],
                ),
                const SizedBox(height: 32),
                const Center(
                  child: Text('Smart Office  •  Queue & Token Management',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide, required this.waiting, required this.departments});

  final bool wide;
  final int waiting;
  final int departments;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 40 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sidebar, AppColors.accent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Skip the line.\nGet your token online.',
              style: TextStyle(color: Colors.white, fontSize: wide ? 38 : 26, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 12),
          const Text('Choose a department, take a token, and follow your place in the queue in real time.',
              style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4)),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _HeroPill(icon: Icons.groups, text: '$waiting waiting now'),
              _HeroPill(icon: Icons.apartment, text: '$departments departments'),
              const _HeroPill(icon: Icons.update, text: 'Live updates'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
        ],
      ),
    );
  }
}
