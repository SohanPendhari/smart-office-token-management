import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../providers/providers.dart';
import '../screens/settings/server_settings_screen.dart';
import '../screens/staff/login_screen.dart';
import '../screens/staff/staff_shell.dart';
import '../screens/visitor/my_tokens_screen.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';

/// Top bar for every visitor screen: brand, navigation, settings.
class PublicAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const PublicAppBar({super.key, this.title});

  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = isTablet(context);
    final loggedIn = ref.watch(authProvider).isLoggedIn;
    final canPop = Navigator.of(context).canPop();
    final staffPage = loggedIn ? const StaffShell() : const LoginScreen();
    final staffLabel = loggedIn ? 'Staff Dashboard' : 'Staff Login';

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        children: [
          if (canPop) IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.apartment, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(AppConfig.appName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
                ],
              ),
            ),
          ),
          if (title != null && wide) ...[
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
            Flexible(
              child: Text(title!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
      actions: [
        if (wide) ...[
          TextButton.icon(
            onPressed: () => _push(context, const MyTokensScreen()),
            icon: const Icon(Icons.confirmation_number_outlined),
            label: const Text('My Tokens'),
          ),
          TextButton.icon(
            onPressed: () => _push(context, staffPage),
            icon: const Icon(Icons.badge_outlined),
            label: Text(staffLabel),
          ),
        ] else ...[
          IconButton(
              tooltip: 'My Tokens',
              icon: const Icon(Icons.confirmation_number_outlined),
              onPressed: () => _push(context, const MyTokensScreen())),
          IconButton(tooltip: staffLabel, icon: const Icon(Icons.badge_outlined), onPressed: () => _push(context, staffPage)),
        ],
        IconButton(
          tooltip: 'Server settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => _push(context, const ServerSettingsScreen()),
        ),
        const SizedBox(width: 8),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: AppColors.border),
      ),
    );
  }
}
