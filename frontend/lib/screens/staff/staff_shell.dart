import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../models/department.dart';
import '../../models/user.dart';
import '../../providers/providers.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import 'dashboard_screen.dart';
import 'department_queue_screen.dart';

/// Staff area: permanent sidebar on desktop, drawer on small screens.
class StaffShell extends ConsumerStatefulWidget {
  const StaffShell({super.key});

  @override
  ConsumerState<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends ConsumerState<StaffShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int? _deptId; // null = dashboard

  void _select(int? id) {
    setState(() => _deptId = id);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.of(context).pop();
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _visitorView() => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    if (!auth.isLoggedIn || user == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(onPressed: _visitorView, child: const Text('Session ended - back to home')),
        ),
      );
    }

    final depts = ref.watch(departmentsProvider).valueOrNull ?? <Department>[];
    String title = 'Dashboard';
    if (_deptId != null) {
      for (final d in depts) {
        if (d.id == _deptId) title = d.name;
      }
      if (title == 'Dashboard') title = 'Department queue';
    }

    final sidebar = _Sidebar(
      user: user,
      departments: depts,
      selected: _deptId,
      onSelect: _select,
      onLogout: _logout,
      onVisitorView: _visitorView,
    );

    final body = _deptId == null
        ? DashboardView(onOpenDepartment: _select)
        : DepartmentQueueView(key: ValueKey<int>(_deptId!), departmentId: _deptId!);

    if (isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(width: 272, child: sidebar),
            Expanded(
              child: Column(
                children: [
                  _TopBar(title: title, user: user),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
      drawer: Drawer(backgroundColor: AppColors.sidebar, child: sidebar),
      body: body,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.user});
  final String title;
  final User user;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(width: 16),
          const Pill('Live', color: AppColors.serving, background: Color(0xFFDCFCE7), icon: Icons.sensors),
          const Spacer(),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(user.isAdmin ? 'Administrator' : 'Staff', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.user,
    required this.departments,
    required this.selected,
    required this.onSelect,
    required this.onLogout,
    required this.onVisitorView,
  });

  final User user;
  final List<Department> departments;
  final int? selected;
  final void Function(int?) onSelect;
  final VoidCallback onLogout;
  final VoidCallback onVisitorView;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.apartment, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(AppConfig.appName,
                      style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _NavTile(icon: Icons.dashboard_outlined, label: 'Dashboard', selected: selected == null, onTap: () => onSelect(null)),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 22, 12, 8),
                    child: Text('DEPARTMENTS',
                        style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  ),
                  for (final d in departments)
                    _NavTile(
                      icon: departmentIcon(d.code),
                      label: d.name,
                      selected: selected == d.id,
                      badge: d.isPaused ? 'paused' : '${d.waiting}',
                      onTap: () => onSelect(d.id),
                    ),
                ],
              ),
            ),
            const Divider(color: Color(0x33FFFFFF), height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _NavTile(icon: Icons.public, label: 'Visitor view', selected: false, onTap: onVisitorView),
                  _NavTile(icon: Icons.logout, label: 'Sign out', selected: false, onTap: onLogout),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(user.email,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.selected, required this.onTap, this.badge});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? const Color(0x26FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? Colors.white : const Color(0xCCFFFFFF)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: selected ? Colors.white : const Color(0xCCFFFFFF),
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(10)),
                    child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
