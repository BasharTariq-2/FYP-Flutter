import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/api_repository.dart';
import '../../widgets/ui.dart';
import '../farms/farm_list_screen.dart';

enum SignupRole {
  owner,
  manager,
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final repo = ApiRepository();

  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final ownerEmail = TextEditingController();

  SignupRole selectedRole = SignupRole.owner;

  bool loading = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    ownerEmail.dispose();
    super.dispose();
  }

  String get selectedRoleText {
    return selectedRole == SignupRole.owner ? 'Owner' : 'Manager';
  }

  bool _validate() {
    final u = username.text.trim();
    final e = email.text.trim();
    final p = password.text;
    final cp = confirmPassword.text;
    final oe = ownerEmail.text.trim();

    if (u.isEmpty) {
      error = 'Username is required';
      return false;
    }

    if (e.isEmpty || !e.contains('@')) {
      error = 'Valid email is required';
      return false;
    }

    if (p.length < 6) {
      error = 'Password must be at least 6 characters';
      return false;
    }

    if (p != cp) {
      error = 'Passwords do not match';
      return false;
    }

    if (selectedRole == SignupRole.manager && oe.isEmpty) {
      error = 'Owner email is required for Manager account';
      return false;
    }

    return true;
  }
  Future<void> _signup() async {

    setState(() => error = null);

    if (!_validate()) {
      setState(() {});
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {

      // Register User
      if (selectedRole == SignupRole.owner) {

        await repo.registerOwner(
          username.text.trim(),
          email.text.trim(),
          password.text.trim(),
        );

      } else {

        await repo.registerManager(
          username.text.trim(),
          email.text.trim(),
          password.text.trim(),
          ownerEmail.text.trim(),
        );
      }

      // Save User Data Locally
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'name',
        username.text.trim(),
      );

      await prefs.setString(
        'email',
        email.text.trim(),
      );

      await prefs.setString(
        'role',
        selectedRoleText,
      );

      await prefs.setBool(
        'isLoggedIn',
        true,
      );

      if (!mounted) return;

      // Success Message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$selectedRoleText account created successfully',
          ),
        ),
      );

      // Navigate
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const FarmListScreen(),
        ),
      );

    } catch (e) {

      setState(() {
        error = e.toString();
      });

    } finally {

      if (mounted) {
        setState(() => loading = false);
      }
    }
  }
  Widget _roleCard({
    required SignupRole role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = selectedRole == role;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: loading
            ? null
            : () {
                setState(() {
                  selectedRole = role;
                  error = null;
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF16806A).withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0xFF16806A) : Colors.grey.shade300,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF16806A) : Colors.black54,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selected ? const Color(0xFF16806A) : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isManager = selectedRole == SignupRole.manager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_add_alt_1,
                    size: 58,
                    color: Color(0xFF16806A),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Smart Poultry Farm',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose Owner or Manager account',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 22),

                  ErrorBox(message: error),

                  Row(
                    children: [
                      _roleCard(
                        role: SignupRole.owner,
                        icon: Icons.admin_panel_settings,
                        title: 'Owner',
                        subtitle: 'Create farms and manage all modules',
                      ),
                      const SizedBox(width: 12),
                      _roleCard(
                        role: SignupRole.manager,
                        icon: Icons.manage_accounts,
                        title: 'Manager',
                        subtitle: 'Join under owner email',
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  AppInput(controller: username, label: 'Username'),
                  AppInput(
                    controller: email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),

                  if (isManager) ...[
                    AppInput(
                      controller: ownerEmail,
                      label: 'Owner Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],

                  AppInput(
                    controller: password,
                    label: 'Password',
                    password: true,
                  ),
                  AppInput(
                    controller: confirmPassword,
                    label: 'Confirm Password',
                    password: true,
                  ),

                  const SizedBox(height: 8),

                  PrimaryButton(
                    text: loading ? 'Creating $selectedRoleText...' : 'Create $selectedRoleText Account',
                    loading: loading,
                    onPressed: _signup,
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: loading ? null : () => Navigator.pop(context),
                    child: const Text('Already have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}