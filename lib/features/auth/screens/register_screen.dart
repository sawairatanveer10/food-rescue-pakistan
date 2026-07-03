import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/auth_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../services/firebase_auth_service.dart';
import '../../donor/screens/donor_dashboard.dart';
import '../../ngo/screens/ngo_dashboard.dart';

enum _RegisterStep { fillForm, enterOtp }

class RegisterScreen extends StatefulWidget {
  final String initialRole;
  const RegisterScreen({super.key, required this.initialRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = FirebaseAuthService();
  final _formKey = GlobalKey<FormState>();

  late String _selectedRole;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _ngoLicenseController = TextEditingController();
  final TextEditingController _ngoTypeController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  _RegisterStep _step = _RegisterStep.fillForm;
  bool _isLoading = false;
  String? _demoOtpBanner;
  String _phoneE164 = '';

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    final e164 = PhoneUtils.toE164(_phoneController.text.trim());
    if (!PhoneUtils.isValid(e164)) {
      _showSnack('Please enter a valid Pakistani phone number', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final existing = await _authService.fetchUserProfile(e164);
      if (existing != null) {
        setState(() => _isLoading = false);
        _showSnack('This phone number is already registered. Please log in instead.', isError: true);
        return;
      }

      final result = await _authService.sendOtp(phoneNumberE164: e164);
      setState(() => _isLoading = false);

      if (result.success) {
        setState(() {
          _phoneE164 = e164;
          _step = _RegisterStep.enterOtp;
          _demoOtpBanner = result.demoOtp;
        });
      } else if (result.cooldownSecondsRemaining != null) {
        _showSnack('Please wait ${result.cooldownSecondsRemaining}s before resending');
      } else {
        _showSnack(result.errorMessage ?? 'Could not send code', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Error: ${e.toString()}', isError: true);
      debugPrint('_sendCode error: $e');
    }
  }

  Future<void> _verifyAndRegister() async {
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
      _showSnack(verifyResult.errorMessage ?? 'Verification failed', isError: true);
      return;
    }

    try {
      final profile = await _authService.createUserProfile(
        phoneNumberE164: _phoneE164,
        role: _selectedRole,
        name: _nameController.text.trim(),
        city: _cityController.text.trim(),
        licenseNumber: _ngoLicenseController.text.trim(),
        ngoType: _ngoTypeController.text.trim(),
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      final user = UserModel.fromMap(profile);
      await context.read<AppAuthProvider>().setUser(user);

      if (!mounted) return;
      _showSnack('Account created successfully!');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => user.role == 'ngo' ? const NgoDashboard() : const DonorDashboard(),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isNgo = _selectedRole == 'NGO';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F5132),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.22,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF0F5132), Color(0xFF198754)]),
                borderRadius:
                    BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, size: 50, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    _step == _RegisterStep.fillForm ? "Create New Account" : "Verify Your Number",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _step == _RegisterStep.fillForm
                        ? "Join us to combat food wastage in Pakistan"
                        : "Enter the code we sent you",
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _step == _RegisterStep.fillForm ? _buildForm(isNgo) : _buildOtpStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isNgo) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _roleToggleCard('Donor', Icons.card_giftcard, _selectedRole == 'Donor')),
              const SizedBox(width: 16),
              Expanded(child: _roleToggleCard('NGO', Icons.corporate_fare, _selectedRole == 'NGO')),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter name' : null,
            decoration: _inputStyle('Full Name / Organization Name', Icons.person),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter phone number' : null,
            decoration: _inputStyle('Phone Number (e.g., 3001234567)', Icons.phone_android),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter city' : null,
            decoration: _inputStyle('City Name', Icons.location_city),
          ),
          const SizedBox(height: 16),
          if (isNgo) ...[
            TextFormField(
              controller: _ngoLicenseController,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'License ID required' : null,
              decoration: _inputStyle('Govt License / Registration Number', Icons.assignment_turned_in),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ngoTypeController,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Specify NGO type' : null,
              decoration: _inputStyle('NGO Type (e.g. Food Bank, Trust)', Icons.category),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF198754)))
              : ElevatedButton(
                  onPressed: _sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF198754),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Send Verification Code',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
        ],
      ),
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
          decoration: _inputStyle('Verification Code', Icons.lock_clock_outlined),
        ),
        const SizedBox(height: 8),
        _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF198754)))
            : ElevatedButton(
                onPressed: _verifyAndRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF198754),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Verify & Create Account',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : () => setState(() => _step = _RegisterStep.fillForm),
          child: const Text('Edit details'),
        ),
      ],
    );
  }

  Widget _roleToggleCard(String name, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF198754) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF198754), size: 24),
            const SizedBox(height: 4),
            Text(name,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF198754)),
    );
  }
}