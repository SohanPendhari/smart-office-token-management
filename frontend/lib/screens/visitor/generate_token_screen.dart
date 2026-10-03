import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/department.dart';
import '../../models/visitor.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../utils/ui.dart';
import '../../utils/validators.dart';
import '../../widgets/app_card.dart';
import '../../widgets/public_app_bar.dart';
import 'token_screen.dart';

class GenerateTokenScreen extends ConsumerStatefulWidget {
  const GenerateTokenScreen({super.key, required this.department});
  final Department department;

  @override
  ConsumerState<GenerateTokenScreen> createState() => _GenerateTokenScreenState();
}

class _GenerateTokenScreenState extends ConsumerState<GenerateTokenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  bool _priority = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final token = await ref.read(tokenServiceProvider).generate(
            widget.department.id,
            VisitorInput(name: _name.text.trim(), mobile: _mobile.text.trim(), priority: _priority),
          );
      await ref.read(myTokensProvider.notifier).add(token.id);
      ref.invalidate(departmentsProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => TokenScreen(tokenId: token.id)));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.department;
    return Scaffold(
      appBar: PublicAppBar(title: 'Generate token'),
      body: ScrollPage(
        maxWidth: 560,
        child: AppCard(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DepartmentBadge(code: d.code, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('New token', style: TextStyle(color: AppColors.textMuted)),
                          Text(d.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                  validator: Validators.name,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  onFieldSubmitted: (_) => _busy ? null : _submit(),
                  decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: Validators.mobile,
                ),
                if (d.allowVisitorPriority) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Priority request', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Served before normal tokens (never interrupts someone being served)'),
                    value: _priority,
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Generate Token'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
