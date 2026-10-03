import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../utils/ui.dart';
import '../../widgets/app_card.dart';
import '../../widgets/public_app_bar.dart';

/// Lets the user point the app at the backend (same PC, another device on the LAN, or emulator).
class ServerSettingsScreen extends ConsumerStatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  ConsumerState<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen> {
  late final TextEditingController _url;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: ref.read(apiBaseUrlProvider));
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final candidate = ApiConfig.normalize(_url.text);
    try {
      await ApiService(baseUrl: () => candidate, authToken: () => null).get('/api/health');
      if (mounted) showSnack(context, 'Connected to $candidate');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    await ref.read(apiBaseUrlProvider.notifier).save(_url.text);
    if (!mounted) return;
    showSnack(context, 'API URL saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PublicAppBar(title: 'Server settings'),
      body: ScrollPage(
        maxWidth: 640,
        child: AppCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Server settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Where the Smart Office backend is running.', style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 24),
              const Text('API base URL', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'http://localhost:8080'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.computer, size: 18),
                    label: const Text('This PC (localhost)'),
                    onPressed: () => setState(() => _url.text = ApiConfig.localUrl),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.phone_android, size: 18),
                    label: const Text('Android emulator'),
                    onPressed: () => setState(() => _url.text = ApiConfig.emulatorUrl),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Browser on the same PC as the backend: http://localhost:8080\n'
                'Another PC or phone on the same Wi-Fi: use the backend PC\'s IP address, '
                'e.g. http://192.168.1.10:8080 (run "ipconfig" on Windows to find it). '
                'You may need to allow port 8080 in Windows Firewall.\n'
                'Android emulator: http://10.0.2.2:8080',
                style: TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _test,
                      icon: _testing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_tethering),
                      label: const Text('Test connection'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: _save, child: const Text('Save'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
