import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/ui.dart';
import '../../core/api_config.dart';
import '../farms/farm_list_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool loading = false;
  bool obscurePassword = true; // ✅ ADDED EYE TOGGLE STATE

  String? error;

  Future<void> _login() async {
    if (username.text.trim().isEmpty || password.text.trim().isEmpty) {
      setState(() {
        error = 'Username and password required';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username.text.trim(),
          'password': password.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('isLoggedIn', true);
        await prefs.setString(
          'name',
          data['username'] ?? username.text.trim(),
        );
        await prefs.setString('email', data['email'] ?? '');
        await prefs.setString('role', data['role'] ?? 'owner');

        if (data['access_token'] != null) {
          await prefs.setString('jwt_token', data['access_token']);
        }

        if (data['role'] == 'manager' &&
            data['owner_email'] != null) {
          await prefs.setString(
            'owner_email',
            data['owner_email'],
          );
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const FarmListScreen(),
          ),
        );
      } else {
        setState(() {
          error = 'Invalid credentials';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 80,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Smart Poultry Farm',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Welcome to Smart Poultry Farm Management System',
                    style: TextStyle(color: Colors.black54),
                  ),

                  const SizedBox(height: 24),

                  ErrorBox(message: error),

                  AppInput(
                    controller: username,
                    label: 'Username',
                  ),

                  const SizedBox(height: 12),

                  // ✅ PASSWORD WITH EYE ICON
                  TextField(
                    controller: password,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  PrimaryButton(
                    text: 'Login',
                    loading: loading,
                    onPressed: _login,
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const SignupScreen(),
                        ),
                      );
                    },
                    child: const Text('Create owner account'),
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