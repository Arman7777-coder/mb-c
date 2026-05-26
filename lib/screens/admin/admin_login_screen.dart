import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _controller = TextEditingController();
  bool _error = false;
  bool _loading = false;

  Future<void> _login() async {
    if (_controller.text.isEmpty) return;
    setState(() { _error = false; _loading = true; });
    try {
      final api = ref.read(apiServiceProvider);
      api.setAdminPassword(_controller.text);
      await api.getAdminDashboard();
      if (mounted) Navigator.pushReplacementNamed(context, '/admin/dashboard');
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Access')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings, size: 64, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text('Admin Panel', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Enter admin password to continue', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: _error ? 'Invalid password' : null,
                prefixIcon: const Icon(Icons.lock),
              ),
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
