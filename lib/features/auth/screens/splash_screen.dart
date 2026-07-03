import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../donor/screens/donor_dashboard.dart';
import '../../ngo/screens/ngo_dashboard.dart';
import 'login_screen.dart';

class NaikiSplashScreen extends StatefulWidget {
  const NaikiSplashScreen({super.key});

  @override
  State<NaikiSplashScreen> createState() => _NaikiSplashScreenState();
}

class _NaikiSplashScreenState extends State<NaikiSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _opacity = 1.0);
    });

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final authProvider = context.read<AppAuthProvider>();
    // Restore any saved session and show the splash for a minimum time,
    // whichever takes longer, so it doesn't flash instantly on fast devices.
    await Future.wait([
      authProvider.loadSession(),
      Future.delayed(const Duration(milliseconds: 2200)),
    ]);

    if (!mounted) return;

    if (authProvider.isLoggedIn) {
      final role = authProvider.currentUser!.role;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'ngo' ? const NgoDashboard() : const DonorDashboard(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F5132), Color(0xFF198754)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  size: 80,
                  color: Color(0xFF198754),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 800),
              child: Column(
                children: [
                  const Text(
                    'NAIKI',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connecting Hearts, Sharing Food',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}