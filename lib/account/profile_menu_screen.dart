import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart'; //

class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});

  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  String userName = '';
  String userEmail = '';

  final List<String> history = [
    'Logged In',
    'Added New Shed',
    'Updated Feed Record',
    'Viewed Temperature Advisory',
  ];

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      userName = prefs.getString('name') ?? 'Farmer';
      userEmail = prefs.getString('email') ?? 'farmer@gmail.com';
    });
  }

  // ✅ FIXED LOGOUT
  Future<void> logout() async {
    Navigator.pop(context); // close drawer first

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  void showAccountDetails() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('My Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 35,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'F',
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              userName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(userEmail),
          ],
        ),
      ),
    );
  }

  void showHistory() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Activity History'),
        content: SizedBox(
          width: 350,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: history.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(history[index]),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.purple.shade100,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'F',
                style: const TextStyle(fontSize: 32),
              ),
            ),

            const SizedBox(height: 15),

            Text(
              userName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              userEmail,
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const SizedBox(height: 30),

            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My Account'),
              onTap: showAccountDetails,
            ),

            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),

            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: showHistory,
            ),

            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('Help & Support'),
                    content: Text('Contact: bashshar.tariq@gmail.com'),
                  ),
                );
              },
            ),

            // ✅ LOGOUT (FIXED)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: logout,
            ),
          ],
        ),
      ),
    );
  }
}