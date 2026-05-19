import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _controller = TextEditingController();
  bool _error = false;

  void _login() {
    if (_controller.text == AppConstants.adminPassword) {
      Navigator.pushReplacementNamed(context, '/admin/dashboard');
    } else {
      setState(() => _error = true);
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
              child: ElevatedButton(onPressed: _login, child: const Text('Login')),
            ),
          ],
        ),
      ),
    );
  }
}
