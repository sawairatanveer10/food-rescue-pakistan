import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:naiki_app/features/auth/screens/login_screen.dart';
import '../../../core/providers/auth_provider.dart';

class NgoDashboard extends StatefulWidget {
  const NgoDashboard({super.key});

  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Position? _currentNgoPosition;
  List<Map<dynamic, dynamic>> _nearbyDonations = [];
  List<Map<dynamic, dynamic>> _myClaimedDonations = [];
  Set<Marker> _mapMarkers = {};
  bool _isLoading = true;
  int _currentTab = 0;

  Timer? _tickTimer;
  StreamSubscription<DatabaseEvent>? _donationsSubscription;

  @override
  void initState() {
    super.initState();
    _getNgoLocationAndFetchDonations();
    // Re-render every second so the countdown labels stay live.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _donationsSubscription?.cancel();
    super.dispose();
  }

  void _getNgoLocationAndFetchDonations() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnack('Please turn on device location (GPS).', isError: true);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnack('Location permanently denied. Enable it from app settings.', isError: true);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      if (!mounted) return;
      setState(() => _currentNgoPosition = position);

      final myUid = FirebaseAuth.instance.currentUser?.uid;

      _donationsSubscription = _dbRef.child('donations').onValue.listen((event) {
        if (!mounted) return;
        if (event.snapshot.value == null) {
          setState(() {
            _nearbyDonations = [];
            _myClaimedDonations = [];
            _mapMarkers = {};
            _isLoading = false;
          });
          return;
        }

        final donationsMap = event.snapshot.value as Map<dynamic, dynamic>;
        final tempNearby = <Map<dynamic, dynamic>>[];
        final tempClaimed = <Map<dynamic, dynamic>>[];
        final tempMarkers = <Marker>{};

        donationsMap.forEach((key, value) {
          if (value is! Map) return;
          if (value['latitude'] == null || value['longitude'] == null) return;

          final donorLat = double.tryParse(value['latitude'].toString());
          final donorLng = double.tryParse(value['longitude'].toString());
          if (donorLat == null || donorLng == null) return;

          final distanceInMeters =
              Geolocator.distanceBetween(position.latitude, position.longitude, donorLat, donorLng);
          value['distance'] = (distanceInMeters / 1000).toStringAsFixed(1);

          if (value['status'] == 'available' && distanceInMeters <= 5000) {
            tempNearby.add(value);
            tempMarkers.add(
              Marker(
                markerId: MarkerId(value['id'].toString()),
                position: LatLng(donorLat, donorLng),
                infoWindow: InfoWindow(title: value['title']?.toString(), snippet: "${value['distance']} km away"),
              ),
            );
          } else if (value['status'] == 'claimed_by_ngo' && value['claimedBy'] == myUid) {
            // Only show claims that belong to *this* NGO.
            tempClaimed.add(value);
          }
        });

        if (mounted) {
          setState(() {
            _nearbyDonations = tempNearby;
            _myClaimedDonations = tempClaimed;
            _mapMarkers = tempMarkers;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error loading donations: $e', isError: true);
      }
    }
  }

  /// Atomically claims a donation only if it's still 'available', preventing
  /// two NGOs from claiming the same donation at the same time.
  Future<void> _claimFood(String donationId) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      _showSnack('Your session expired. Please log in again.', isError: true);
      return;
    }

    final ref = _dbRef.child('donations').child(donationId);

    try {
      final result = await ref.runTransaction((Object? currentData) {
        if (currentData == null) {
          return Transaction.abort();
        }
        final data = Map<String, dynamic>.from(currentData as Map);
        if (data['status'] != 'available') {
          // Someone else already claimed it — abort without changing anything.
          return Transaction.abort();
        }
        data['status'] = 'claimed_by_ngo';
        data['claimedBy'] = myUid;
        return Transaction.success(data);
      });

      if (!mounted) return;

      if (result.committed) {
        _showSnack('Food Successfully Claimed for Collection!');
      } else {
        _showSnack('Sorry, this donation was just claimed by another NGO.', isError: true);
      }
    } catch (e) {
      _showSnack('Error claiming donation: $e', isError: true);
    }
  }

  String _getCountdownText(dynamic expiryTime) {
    if (expiryTime == null) return "No Limit";
    final expiry = int.tryParse(expiryTime.toString());
    if (expiry == null) return "Unknown";

    final remaining = expiry - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return "Expired";

    final duration = Duration(milliseconds: remaining);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds left";
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : null),
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
    final isVerified = authProvider.currentUser?.isVerified ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_currentTab == 0 ? 'NGO Live Radar Scan (5km)' : 'Your Claimed Collections',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F5132),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          )
        ],
      ),
      body: Column(
        children: [
          if (!isVerified)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.pending_outlined, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Verification pending — your registration number is being reviewed.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF198754)))
                : _currentTab == 0
                    ? _buildRadarView()
                    : _buildClaimsHistoryView(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        selectedItemColor: const Color(0xFF198754),
        unselectedItemColor: Colors.grey[500],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar_rounded), label: 'Live Radar'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_rounded), label: 'My Claims'),
        ],
      ),
    );
  }

  Widget _buildRadarView() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration:
                BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
            clipBehavior: Clip.antiAlias,
            child: _currentNgoPosition == null
                ? const Center(child: Text('Map Loading...'))
                : GoogleMap(
                    initialCameraPosition:
                        CameraPosition(target: LatLng(_currentNgoPosition!.latitude, _currentNgoPosition!.longitude), zoom: 13),
                    markers: _mapMarkers,
                    myLocationEnabled: true,
                  ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.fastfood, color: Color(0xFF198754), size: 20),
              SizedBox(width: 8),
              Text("Available Donations Near You", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: _nearbyDonations.isEmpty
              ? const Center(child: Text('No active food requests found within 5km radius.'))
              : ListView.builder(
                  itemCount: _nearbyDonations.length,
                  itemBuilder: (context, index) {
                    final item = _nearbyDonations[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.1))),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.restaurant, color: Color(0xFF198754))),
                        title: Text(item['title'] ?? 'Food Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text("Donor: ${item['donorName'] ?? 'Anonymous Donor'}",
                                style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text("Serves: ${item['quantity']} | Dist: ${item['distance']} km", style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text(
                              "Expires in: ${_getCountdownText(item['expiryTime'])}",
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      trailing: SizedBox(
  width: 80,
  child: ElevatedButton(
    onPressed: () => _claimFood(item['id']),
    style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.orange[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    child: const Text('Claim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  ),
),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildClaimsHistoryView() {
    return _myClaimedDonations.isEmpty
        ? const Center(child: Text('You haven\'t claimed any food requests yet.'))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _myClaimedDonations.length,
            itemBuilder: (context, index) {
              final item = _myClaimedDonations[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withOpacity(0.15))),
                color: Colors.white,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.1), child: const Icon(Icons.done_all, color: Colors.orange)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'] ?? 'Package Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text("By: ${item['donorName'] ?? 'Anonymous Donor'}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            const SizedBox(height: 2),
                            Text("Serves: ${item['quantity']}", style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Chip(
                        label: const Text("Assigned", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        backgroundColor: const Color(0xFF198754),
                        padding: EdgeInsets.zero,
                      )
                    ],
                  ),
                ),
              );
            },
          );
  }
}