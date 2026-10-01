import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/error_box.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _ownerEmailController = TextEditingController();
  String _role = 'Owner';
  bool _loading = false;
  String? _error;

  Future<void> _signup() async {
    if (_usernameController.text.trim().length < 3) { setState(() => _error = 'Username must be at least 3 characters'); return; }
    if (!_emailController.text.contains('@')) { setState(() => _error = 'Please enter a valid email'); return; }
    if (_passwordController.text.length < 6) { setState(() => _error = 'Password must be at least 6 characters'); return; }
    if (_passwordController.text != _confirmPasswordController.text) { setState(() => _error = 'Passwords do not match'); return; }
    if (_role == 'Manager' && _ownerEmailController.text.trim().isEmpty) { setState(() => _error = 'Owner email is required'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      if (_role == 'Owner') await _authService.registerOwner(_usernameController.text.trim(), _emailController.text.trim(), _passwordController.text);
      else await _authService.registerManager(_usernameController.text.trim(), _emailController.text.trim(), _passwordController.text, _ownerEmailController.text.trim());
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } catch (e) { setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), backgroundColor: Colors.transparent, elevation: 0),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.teal.shade600, Colors.teal.shade800])),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AppCard(
                child: Column(children: [
                  const Text('🐔', style: TextStyle(fontSize: 60)),
                  const Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Select your role carefully!', style: TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(height: 24),
                  Row(children: [
                    _buildRoleCard('Owner', Icons.verified, _role == 'Owner'),
                    const SizedBox(width: 12),
                    _buildRoleCard('Manager', Icons.manage_accounts, _role == 'Manager'),
                  ]),
                  const SizedBox(height: 24),
                  ErrorBox(message: _error),
                  AppInput(controller: _usernameController, label: 'Username (min 3 chars)'),
                  const SizedBox(height: 12),
                  AppInput(controller: _emailController, label: 'Email', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  if (_role == 'Manager') AppInput(controller: _ownerEmailController, label: 'Owner Email', keyboardType: TextInputType.emailAddress),
                  AppInput(controller: _passwordController, label: 'Password (min 6 chars)', obscureText: true),
                  const SizedBox(height: 12),
                  AppInput(controller: _confirmPasswordController, label: 'Confirm Password', obscureText: true),
                  const SizedBox(height: 24),
                  PrimaryButton(text: _loading ? 'Creating...' : 'Sign Up as $_role', loading: _loading, onPressed: _signup),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Already have an account? Sign In')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String title, IconData icon, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = title),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Colors.teal : Colors.grey.shade300, width: isSelected ? 2 : 1),
          ),
          child: Column(children: [
            Icon(icon, size: 28, color: isSelected ? Colors.teal : Colors.grey),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.teal : Colors.grey)),
          ]),
        ),
      ),
    );
  }
}