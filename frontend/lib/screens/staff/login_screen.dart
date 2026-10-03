import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../utils/ui.dart';
import '../../utils/validators.dart';
import 'staff_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).login(_email.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const StaffShell()));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Staff sign in', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Sign in to manage your department queue.', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 28),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _hide,
            onFieldSubmitted: (_) => _busy ? null : _login(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            validator: Validators.password,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _login,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final formPanel = Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _form()),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to home'),
          ),
        ),
      ],
    );

    if (!desktop) return Scaffold(backgroundColor: Colors.white, body: SafeArea(child: formPanel));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(56),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.sidebar, AppColors.accent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.apartment, size: 56, color: Colors.white),
                  SizedBox(height: 20),
                  Text(AppConfig.appName,
                      style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text(AppConfig.tagline, style: TextStyle(color: Colors.white70, fontSize: 18)),
                  SizedBox(height: 40),
                  _Feature(icon: Icons.campaign, text: 'Call, complete and transfer tokens in one click'),
                  _Feature(icon: Icons.star, text: 'Priority tokens never interrupt a visitor being served'),
                  _Feature(icon: Icons.insights, text: 'Live dashboard with waiting and service times'),
                ],
              ),
            ),
          ),
          Expanded(flex: 4, child: formPanel),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 14),
          Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16))),
        ],
      ),
    );
  }
}
