import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:naiki_app/features/auth/screens/login_screen.dart';
import '../../../core/providers/auth_provider.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _foodTitleController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isAnonymous = false;
  int _expiryHours = 4;
  bool _isSubmitting = false;

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _showSnack('Please turn on device location (GPS) to post a donation.', isError: true);
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        _showSnack('Location permission is required to post a donation.', isError: true);
      }
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showSnack(
          'Location is permanently denied. Please enable it from app settings.',
          isError: true,
        );
      }
      return false;
    }

    return true;
  }

  void _submitDonation() async {
    if (_foodTitleController.text.trim().isEmpty || _quantityController.text.trim().isEmpty) {
      _showSnack('Please fill all required fields');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('Your session expired. Please log in again.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        setState(() => _isSubmitting = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);

      final authProvider = context.read<AppAuthProvider>();
      final realName = authProvider.currentUser?.name ?? 'Registered Donor';
      final donorPhone = authProvider.currentUser?.phone ?? '';

      final int nowEpoch = DateTime.now().millisecondsSinceEpoch;
      final int expiryEpoch = nowEpoch + (_expiryHours * 60 * 60 * 1000);

      // push() generates a globally unique, collision-proof key.
      final newRef = _dbRef.child('donations').push();
      final donationId = newRef.key!;

      await newRef.set({
        'id': donationId,
        'donorId': uid,
        'donorPhone': donorPhone,
        'title': _foodTitleController.text.trim(),
        'quantity': _quantityController.text.trim(),
        'description': _descriptionController.text.trim(),
        'donorName': _isAnonymous ? 'Anonymous Donor' : realName,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'status': 'available',
        'claimedBy': null,
        'timestamp': ServerValue.timestamp,
        'expiryTime': expiryEpoch,
      });

      if (!mounted) return;
      Navigator.pop(context);
      _clearForm();
      _showSnack('JazakAllah! Donation Posted');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    _foodTitleController.clear();
    _quantityController.clear();
    _descriptionController.clear();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : null),
    );
  }

  void _showDonateForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Post Food Donation',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF198754))),
              const SizedBox(height: 20),
              TextField(
                controller: _foodTitleController,
                decoration: InputDecoration(
                  labelText: 'Food Title (e.g., Biryani)',
                  prefixIcon: const Icon(Icons.fastfood, color: Color(0xFF198754)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity (e.g., 25-30 Plates)',
                  prefixIcon: const Icon(Icons.people, color: Color(0xFF198754)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Expiry notes or details',
                  prefixIcon: const Icon(Icons.description, color: Color(0xFF198754)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _expiryHours,
                decoration: InputDecoration(
                  labelText: 'Freshness/Expiry Window',
                  prefixIcon: const Icon(Icons.timer_outlined, color: Color(0xFF198754)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                dropdownColor: const Color(0xFFF8F9FA),
                items: [2, 4, 6, 12, 24].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('Expires in $value Hours', style: const TextStyle(fontSize: 15)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _expiryHours = val);
                },
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setLocalState) {
                  return SwitchListTile(
                    title: const Text("Donate Anonymously",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: const Text("Hide your identity from NGO dashboard view",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    value: _isAnonymous,
                    activeColor: const Color(0xFF198754),
                    onChanged: (bool value) {
                      setState(() => _isAnonymous = value);
                      setLocalState(() => _isAnonymous = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
              const SizedBox(height: 24),
              _isSubmitting
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF198754)))
                  : ElevatedButton(
                      onPressed: _submitDonation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF198754),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: const Text('Share Food + Live Location',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await context.read<AppAuthProvider>().logout();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final displayName = authProvider.currentUser?.name ?? 'Donor';
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0F5132), Color(0xFF198754)]),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Assalam-o-Alaikum,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                )
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.history, color: Color(0xFF198754), size: 20),
                SizedBox(width: 8),
                Text("Your Active / Past Donations",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _dbRef.child('donations').onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF198754)));
                }
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text('No donations posted yet. Click + to save lives!'));
                }

                final map = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                // Only show donations posted by the currently logged-in donor.
                final myDonations = map.values
                    .whereType<Map<dynamic, dynamic>>()
                    .where((item) => item['donorId'] == currentUid)
                    .toList()
                  ..sort((a, b) =>
                      ((b['timestamp'] ?? 0) as num).compareTo((a['timestamp'] ?? 0) as num));

                if (myDonations.isEmpty) {
                  return const Center(child: Text('No donations posted yet. Click + to save lives!'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: myDonations.length,
                  itemBuilder: (context, index) {
                    final item = myDonations[index];
                    final isClaimed = item['status'] != 'available';

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor:
                              isClaimed ? Colors.orange.withOpacity(0.1) : const Color(0xFF198754).withOpacity(0.1),
                          child: Icon(Icons.fastfood, color: isClaimed ? Colors.orange : const Color(0xFF198754)),
                        ),
                        title: Text(item['title'] ?? 'Food Package',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                              "Serves: ${item['quantity'] ?? 'N/A'}\nStatus: ${isClaimed ? 'Claimed' : 'Available'}"),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isClaimed ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isClaimed ? "NGO Claimed" : "Active",
                            style: TextStyle(
                                color: isClaimed ? Colors.orange[800] : Colors.green[800],
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDonateForm,
        backgroundColor: const Color(0xFF198754),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Donate Food", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}