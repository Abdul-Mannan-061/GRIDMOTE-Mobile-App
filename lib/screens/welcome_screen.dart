import 'home_screen.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF172554),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 90,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'GRIDMOTE',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your devices. Your controls.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Connect your Arduino, load your custom layout, '
                      'and control your devices from your phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Get Started',
                      style: TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Design • Connect • Control',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}