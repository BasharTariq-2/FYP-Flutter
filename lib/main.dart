import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/session_store.dart';
import 'responsive/responsive.dart';
import 'screens/auth/login_screen.dart';
import 'screens/farms/farm_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartPoultryApp());
}

class SmartPoultryApp extends StatelessWidget {
  const SmartPoultryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Poultry Farm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        return ResponsiveInit(child: child ?? const SizedBox());
      },
      home: const StartupGate(),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool loading = true;
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final token = await SessionStore.getToken();
    if (mounted) {
      setState(() {
        loggedIn = token != null && token.isNotEmpty;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return loggedIn ? const FarmListScreen() : const LoginScreen();
  }
}