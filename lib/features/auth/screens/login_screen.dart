import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/auth_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../services/firebase_auth_service.dart';
import '../../donor/screens/donor_dashboard.dart';
import '../../ngo/screens/ngo_dashboard.dart';
import 'register_screen.dart';

enum _LoginStep { enterPhone, enterOtp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = FirebaseAuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String _selectedRole = 'Donor';
  _LoginStep _step = _LoginStep.enterPhone;
  bool _isLoading = false;
  String? _demoOtpBanner;
  String _phoneE164 = '';

  Future<void> _sendCode() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      _showSnack('Please enter your phone number');
      return;
    }

    final e164 = PhoneUtils.toE164(rawPhone);
    if (!PhoneUtils.isValid(e164)) {
      _showSnack('Please enter a valid Pakistani phone number');
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.sendOtp(phoneNumberE164: e164);
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() {
        _phoneE164 = e164;
        _step = _LoginStep.enterOtp;
        _demoOtpBanner = result.demoOtp;
      });
    } else if (result.cooldownSecondsRemaining != null) {
      _showSnack('Please wait ${result.cooldownSecondsRemaining}s before resending');
    } else {
      _showSnack(result.errorMessage ?? 'Could not send code');
    }
  }

  Future<void> _verifyAndLogin() async {
    final code = _otpController.text.trim();
    if (code.length != kOtpLength) {
      _showSnack('Please enter the $kOtpLength-digit code');
      return;
    }

    setState(() => _isLoading = true);

    final verifyResult = await _authService.verifyOtp(
      phoneNumberE164: _phoneE164,
      enteredOtp: code,
    );

    if (!verifyResult.success) {
      setState(() => _isLoading = false);
      _showSnack(verifyResult.errorMessage ?? 'Verification failed');
      return;
    }

    final profile = await _authService.fetchUserProfile(_phoneE164);
    setState(() => _isLoading = false);

    if (profile == null) {
      _showSnack(
        'No ${_selectedRole} account found with this number. Please register first!',
        isError: true,
      );
      return;
    }

    final storedRole = (profile['role']?.toString() ?? '').toLowerCase();
    if (storedRole != _selectedRole.toLowerCase()) {
      _showSnack(
        'This number is registered as ${storedRole == 'ngo' ? 'NGO' : 'Donor'}, not $_selectedRole.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;

    final user = UserModel.fromMap(profile);
    await context.read<AppAuthProvider>().setUser(user);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => storedRole == 'ngo' ? const NgoDashboard() : const DonorDashboard(),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.35,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F5132), Color(0xFF198754)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.volunteer_activism, size: 65, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text(
                    "Welcome to Naiki",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _step == _LoginStep.enterPhone
                        ? "Sign in to continue your journey"
                        : "Enter the code we sent you",
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: _step == _LoginStep.enterPhone ? _buildPhoneStep() : _buildOtpStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _buildRoleCard('Donor', Icons.card_giftcard, _selectedRole == 'Donor')),
            const SizedBox(width: 16),
            Expanded(child: _buildRoleCard('NGO', Icons.corporate_fare, _selectedRole == 'NGO')),
          ],
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '3001234567',
            prefixText: '+92 ',
            prefixIcon: Icon(Icons.phone_android_rounded, color: Color(0xFF198754)),
          ),
        ),
        const SizedBox(height: 32),
        _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF198754)))
            : ElevatedButton(
                onPressed: _sendCode,
                child: const Text('Send Code'),
              ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterScreen(initialRole: _selectedRole),
                  ),
                );
              },
              child: const Text(
                "Register Here",
                style: TextStyle(
                  color: Color(0xFF198754),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kOtpDemoMode && _demoOtpBanner != null)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'DEMO MODE — Real SMS is disabled (billing not enabled). '
                    'Your code is: $_demoOtpBanner',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: kOtpLength,
          decoration: const InputDecoration(
            labelText: 'Verification Code',
            prefixIcon: Icon(Icons.lock_clock_outlined, color: Color(0xFF198754)),
          ),
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF198754)))
            : ElevatedButton(
                onPressed: _verifyAndLogin,
                child: const Text('Verify & Log In'),
              ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() {
                    _step = _LoginStep.enterPhone;
                    _otpController.clear();
                  }),
          child: const Text('Change phone number'),
        ),
      ],
    );
  }

  Widget _buildRoleCard(String roleName, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = roleName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF198754) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF198754).withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: isSelected ? Colors.white : const Color(0xFF198754)),
            const SizedBox(height: 8),
            Text(
              roleName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}