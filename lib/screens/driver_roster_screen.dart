import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

// --- NEW: Import for checking camera permissions before launching the scanner ---
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_colors.dart';
import '../services/ride_service.dart';
import 'qr_scanner_screen.dart';

class DriverRosterScreen extends StatelessWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const DriverRosterScreen({
    super.key,
    required this.rideId,
    required this.rideData,
  });

  String _safeText(dynamic value, String fallback) {
    if (value == null) return fallback;

    final text = value.toString().trim();
    if (text.isEmpty) return fallback;

    return text;
  }

  LatLng? _pickupLatLng(dynamic pickupLocation) {
    if (pickupLocation == null) return null;
    if (pickupLocation is! Map) return null;

    final lat = pickupLocation['lat'];
    final lng = pickupLocation['lng'];

    if (lat == null || lng == null) return null;

    return LatLng(
      (lat as num).toDouble(),
      (lng as num).toDouble(),
    );
  }

  void _showMessage(
    BuildContext context, {
    required String message,
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: AppColors.navy),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _closeLoadingDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmRemovePassenger({
    required BuildContext context,
    required String passengerId,
    required String passengerName,
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Rider?'),
          content: Text(
            'Are you sure you want to remove $passengerName from this ride?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.greyText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!context.mounted) return;
    _showLoadingDialog(context, 'Removing rider...');

    try {
      await RideService().removePassengerFromRide(
        rideId: rideId,
        passengerId: passengerId,
      );

      if (context.mounted) {
        _closeLoadingDialog(context);

        _showMessage(
          context,
          message: 'Passenger removed successfully.',
          isError: false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _closeLoadingDialog(context);

        _showMessage(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  List<MapEntry<String, dynamic>> _activePassengersFromRide(
    Map<String, dynamic> ride,
  ) {
    final roster = ride['passengerRoster'];

    if (roster is! Map) return [];

    final Map<String, dynamic> rosterMap = Map<String, dynamic>.from(roster);

    final List<MapEntry<String, dynamic>> entries =
        rosterMap.entries.where((entry) {
      final value = entry.value;

      if (value is! Map) return false;

      final status = value['bookingStatus']?.toString() ?? 'active';

      return status == RideService.bookingStatusActive;
    }).toList();

    entries.sort((a, b) {
      final aMap = a.value is Map
          ? Map<String, dynamic>.from(a.value)
          : <String, dynamic>{};

      final bMap = b.value is Map
          ? Map<String, dynamic>.from(b.value)
          : <String, dynamic>{};

      final aName = _safeText(aMap['riderName'], '');
      final bName = _safeText(bMap['riderName'], '');

      return aName.compareTo(bName);
    });

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white24,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.white,
                size: 20,
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        ),
        title: const Text(
          'Driver Roster',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder(
        stream: RideService().streamRide(rideId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Could not load roster.',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Ride was not found.',
                style: TextStyle(color: AppColors.greyText),
              ),
            );
          }

          final ride = snapshot.data!.data() as Map<String, dynamic>;

          final String originName = _safeText(ride['originName'], 'Origin');
          final String destinationName =
              _safeText(ride['destinationName'], 'Destination');

          final String rideStatus = ride[RideService.fieldStatus]?.toString() ??
              RideService.statusActive;

          final passengers = _activePassengersFromRide(ride);

          final int availableSeats = ride['availableSeats'] is int
              ? ride['availableSeats']
              : ride['availableSeats'] is num
                  ? (ride['availableSeats'] as num).toInt()
                  : 0;

          final int totalSeats = ride['totalSeats'] is int
              ? ride['totalSeats']
              : ride['totalSeats'] is num
                  ? (ride['totalSeats'] as num).toInt()
                  : 0;

          final bool canRemovePassengers =
              RideService().canCancelRideFromData(ride) ||
                  rideStatus == RideService.statusStarted;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ride Route',
                      style: TextStyle(
                        color: AppColors.greyText,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$originName → $destinationName',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Seats: $availableSeats/$totalSeats available',
                      style: const TextStyle(
                        color: AppColors.greyText,
                        fontSize: 13,
                      ),
                    ),
                    if (!canRemovePassengers) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha:0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Removal is locked 30 minutes before departure.',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _TripStatusPanel(rideId: rideId, ride: ride),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Booked Riders',
                    style: TextStyle(
                      color: AppColors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${passengers.length}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (passengers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: AppColors.greyText,
                        size: 42,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No riders booked yet.',
                        style: TextStyle(
                          color: AppColors.greyText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...passengers.map((entry) {
                  final String passengerId = entry.key;
                  final passenger = Map<String, dynamic>.from(entry.value);

                  return _PassengerCard(
                    rideId: rideId,
                    rideStatus: rideStatus,
                    passengerId: passengerId,
                    passenger: passenger,
                    pickupLatLng: _pickupLatLng(passenger['pickupLocation']),
                    canRemove: canRemovePassengers,
                    onRemove: () => _confirmRemovePassenger(
                      context: context,
                      passengerId: passengerId,
                      passengerName: _safeText(
                        passenger['riderName'],
                        'this rider',
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WHATSAPP HELPER
// ---------------------------------------------------------------------------

Future<void> _openWhatsApp(String rawPhone) async {
  // Strip everything except digits and leading +
  final String digits = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
  final Uri url = Uri.parse('https://wa.me/$digits');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

class _PassengerCard extends StatefulWidget {
  final String rideId;
  final String rideStatus;
  final String passengerId;
  final Map<String, dynamic> passenger;
  final LatLng? pickupLatLng;
  final bool canRemove;
  final VoidCallback onRemove;

  const _PassengerCard({
    required this.rideId,
    required this.rideStatus,
    required this.passengerId,
    required this.passenger,
    required this.pickupLatLng,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  State<_PassengerCard> createState() => _PassengerCardState();
}

class _PassengerCardState extends State<_PassengerCard> {
  bool _isMarkingArrived = false;

  String _safeText(dynamic value, String fallback) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return text;
  }

  Future<void> _markArrived() async {
    setState(() => _isMarkingArrived = true);
    try {
      await RideService().markDriverArrivedAtPassenger(
        rideId: widget.rideId,
        passengerId: widget.passengerId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isMarkingArrived = false);
    }
  }

  Future<void> _openScanner(BuildContext context) async {
    // --- NEW: Ask for OS camera permissions first to prevent black screens ---
    final status = await Permission.camera.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Camera permission is required to scan QR codes.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (!context.mounted) return;

    // 2. Second Async Gap
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          rideId: widget.rideId,
          passengerId: widget.passengerId,
          passengerName: _safeText(widget.passenger['riderName'], 'Rider'),
        ),
      ),
    );

    if (!context.mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Rider scanned and on board!'),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String riderName = _safeText(widget.passenger['riderName'], 'Rider');
    final String riderPhone =
        _safeText(widget.passenger['riderPhone'], 'No phone');
    final String riderImageUrl =
        _safeText(widget.passenger['riderImageUrl'], '');
    final String pickupName =
        _safeText(widget.passenger['pickupName'], 'Saved Home Location');

    final bool isPickedUp =
        widget.passenger[RideService.bookingFieldIsPickedUp] == true;
    final bool driverArrived =
        widget.passenger[RideService.bookingFieldDriverArrivedAt] != null;
    final bool isRideStarted = widget.rideStatus == RideService.statusStarted;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: AppColors.bgLight,
                  shape: BoxShape.circle,
                ),
                child: riderImageUrl.isNotEmpty
                    ? Image.network(
                        riderImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            color: AppColors.greyText,
                            size: 32,
                          );
                        },
                      )
                    : const Icon(
                        Icons.person,
                        color: AppColors.greyText,
                        size: 32,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      riderName,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      riderPhone,
                      style: const TextStyle(
                        color: AppColors.greyText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: widget.canRemove
                    ? 'Remove rider'
                    : 'Removal locked 30 minutes before departure',
                onPressed: widget.canRemove ? widget.onRemove : null,
                icon: Icon(
                  widget.canRemove
                      ? Icons.person_remove_alt_1
                      : Icons.lock_outline,
                  color:
                      widget.canRemove ? Colors.redAccent : AppColors.greyText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: AppColors.navy,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pickupName,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (widget.pickupLatLng != null)
            Container(
              height: 150,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: widget.pickupLatLng!,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.aastmt.campuspool',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.pickupLatLng!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No pickup pin available.',
                style: TextStyle(
                  color: AppColors.greyText,
                  fontSize: 13,
                ),
              ),
            ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: riderPhone == 'No phone'
                  ? null
                  : () => _openWhatsApp(riderPhone),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.bgLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.chat, size: 18),
              label: const Text(
                'Message on WhatsApp',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Per-passenger pickup controls — only visible when ride is started
          if (isRideStarted) ...[
            const SizedBox(height: 10),
            if (isPickedUp)
              // Picked up confirmation badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle,
                        color: Color(0xFF16A34A), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'On Board — Scanned',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  // Arrived at pickup button
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _isMarkingArrived || driverArrived
                            ? null
                            : _markArrived,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: driverArrived
                              ? AppColors.greyText
                              : const Color(0xFFD97706),
                          side: BorderSide(
                            color: driverArrived
                                ? AppColors.greyText
                                : const Color(0xFFD97706),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isMarkingArrived
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFD97706),
                                ),
                              )
                            : Icon(
                                driverArrived
                                    ? Icons.location_on
                                    : Icons.location_on_outlined,
                                size: 16,
                              ),
                        label: Text(
                          driverArrived ? 'Arrived' : 'Mark Arrived',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Scan QR button
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _openScanner(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 16),
                        label: const Text(
                          'Scan QR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
// ---------------------------------------------------------------------------
// TRIP STATUS PANEL
// ---------------------------------------------------------------------------

class _TripStatusPanel extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> ride;

  const _TripStatusPanel({required this.rideId, required this.ride});

  @override
  State<_TripStatusPanel> createState() => _TripStatusPanelState();
}

class _TripStatusPanelState extends State<_TripStatusPanel> {
  bool _isLoading = false;

  // 4 visual steps — "All Picked Up" is computed, not a Firestore status
  static const _stepLabels = [
    'Scheduled',
    'Started',
    'All Picked Up',
    'Completed'
  ];

  static const _stepIcons = [
    Icons.schedule,
    Icons.directions_car,
    Icons.people,
    Icons.check_circle,
  ];

  // Compute pickup progress from the passenger roster
  ({int total, int scanned}) _pickupProgress() {
    final dynamic roster = widget.ride[RideService.fieldPassengerRoster];
    if (roster is! Map) return (total: 0, scanned: 0);
    final rosterMap = Map<String, dynamic>.from(roster);
    final active = rosterMap.values.where((b) {
      if (b is! Map) return false;
      return (b['bookingStatus']?.toString() ??
              RideService.bookingStatusActive) ==
          RideService.bookingStatusActive;
    }).toList();
    final scanned = active
        .where((b) => (b as Map)[RideService.bookingFieldIsPickedUp] == true)
        .length;
    return (total: active.length, scanned: scanned);
  }

  Future<void> _advanceStatus(String currentStatus) async {
    String next;
    String confirmMessage;
    String buttonLabel;
    Color buttonColor;

    if (currentStatus == RideService.statusActive) {
      next = RideService.statusStarted;
      confirmMessage = 'Start the ride?';
      buttonLabel = 'Start Ride';
      buttonColor = const Color(0xFF2563EB);
    } else if (currentStatus == RideService.statusStarted) {
      next = RideService.statusCompleted;
      confirmMessage = 'Mark this ride as completed? This cannot be undone.';
      buttonLabel = 'Complete Ride';
      buttonColor = const Color(0xFF16A34A);
    } else {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(buttonLabel),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.greyText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await RideService().updateTripStatus(
        rideId: widget.rideId,
        newStatus: next,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Status updated: $buttonLabel'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = widget.ride[RideService.fieldStatus]?.toString() ??
        RideService.statusActive;

    final bool isCancelled = status == RideService.statusCancelled;
    final bool isCompleted = status == RideService.statusCompleted;
    final bool isTerminal = isCompleted || isCancelled;
    final bool isStarted = status == RideService.statusStarted;

    final progress = _pickupProgress();
    final bool allScanned =
        progress.total == 0 || progress.scanned == progress.total;

    // Visual step index across 4 steps:
    // 0 = Scheduled, 1 = Started, 2 = All Picked Up, 3 = Completed
    final int currentStepIndex = isCompleted
        ? 3
        : (isStarted && allScanned)
            ? 2
            : isStarted
                ? 1
                : isCancelled
                    ? 0
                    : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Status',
            style: TextStyle(
              color: AppColors.greyText,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // 4-step progress bar
          Row(
            children: List.generate(_stepLabels.length, (i) {
              final bool isDone = currentStepIndex >= i;
              final bool isLast = i == _stepLabels.length - 1;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? (isCancelled
                                      ? Colors.redAccent
                                      : AppColors.navy)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDone
                                    ? (isCancelled
                                        ? Colors.redAccent
                                        : AppColors.navy)
                                    : const Color(0xFFCBD5E1),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _stepIcons[i],
                              size: 18,
                              color: isDone
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _stepLabels[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isDone ? FontWeight.bold : FontWeight.normal,
                              color:
                                  isDone ? AppColors.black : AppColors.greyText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 22),
                          color: currentStepIndex > i
                              ? AppColors.navy
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),

          // Pickup progress counter — shown while ride is started
          if (isStarted && progress.total > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: allScanned
                    ? const Color(0xFF16A34A).withValues(alpha:0.08)
                    : const Color(0xFFD97706).withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    allScanned ? Icons.check_circle : Icons.qr_code_scanner,
                    color: allScanned
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    allScanned
                        ? 'All riders scanned — ready to complete'
                        : '${progress.scanned}/${progress.total} riders scanned',
                    style: TextStyle(
                      color: allScanned
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action button
          if (!isTerminal) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : (isStarted && !allScanned)
                        ? null
                        : () => _advanceStatus(status),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isStarted
                      ? (allScanned
                          ? const Color(0xFF16A34A)
                          : AppColors.greyText)
                      : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(
                        isStarted
                            ? Icons.check_circle_outline
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                label: Text(
                  _isLoading
                      ? 'Updating...'
                      : isStarted
                          ? (allScanned
                              ? 'Complete Ride'
                              : 'Scan All Riders First')
                          : 'Start Ride',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],

          if (isCancelled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cancel_outlined,
                      color: Colors.redAccent, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'This ride has been cancelled.',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
