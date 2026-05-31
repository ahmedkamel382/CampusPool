import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
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

  DateTime? _dateTimeFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatShortDate(DateTime dateTime) {
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _formatTimeOnly(DateTime dateTime) {
    final int hour = dateTime.hour;
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '$displayHour:$minute $period';
  }

  String _formatDepartureRange(dynamic earliestValue, dynamic latestValue) {
    final DateTime? earliest = _dateTimeFromDynamic(earliestValue);
    final DateTime? latest = _dateTimeFromDynamic(latestValue);

    if (earliest == null && latest == null) return 'Not set';

    if (earliest == null) {
      return '${_formatShortDate(latest!)} • ${_formatTimeOnly(latest)}';
    }

    if (latest == null) {
      return '${_formatShortDate(earliest)} • ${_formatTimeOnly(earliest)}';
    }

    final bool sameDate = earliest.year == latest.year &&
        earliest.month == latest.month &&
        earliest.day == latest.day;

    if (sameDate) {
      return '${_formatShortDate(earliest)} • ${_formatTimeOnly(earliest)} - ${_formatTimeOnly(latest)}';
    }

    return '${_formatShortDate(earliest)} • ${_formatTimeOnly(earliest)} - ${_formatShortDate(latest)} • ${_formatTimeOnly(latest)}';
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
    final navigator = Navigator.of(context, rootNavigator: true);

    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  bool _isTerminalStatus(String status) {
    return status == RideService.statusCancelled ||
        status == RideService.statusCompleted;
  }

  bool _isInProgressStatus(String status) {
    return status == RideService.statusStarted ||
        status == RideService.statusArrivedAtPickup;
  }

  bool _isActiveExpiredRide(Map<String, dynamic> ride, String status) {
    return status == RideService.statusActive &&
        RideService().isRideExpired(ride);
  }

  String _rosterLockMessage({
    required String status,
    required bool isExpired,
    required bool canEditRoster,
  }) {
    if (status == RideService.statusCancelled) {
      return 'Roster is read-only because this ride was cancelled.';
    }

    if (status == RideService.statusCompleted) {
      return 'Roster is read-only because this ride is completed.';
    }

    if (isExpired) {
      return 'Roster is read-only because this ride expired before it was started.';
    }

    if (_isInProgressStatus(status)) {
      return 'Roster is locked after the ride starts. Use Scan QR or Mark No-Show.';
    }

    if (!canEditRoster) {
      return 'Removal is locked 30 minutes before departure.';
    }

    return '';
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
    final roster = ride[RideService.fieldPassengerRoster];

    if (roster is! Map) return [];

    final Map<String, dynamic> rosterMap = Map<String, dynamic>.from(roster);

    final List<MapEntry<String, dynamic>> entries =
    rosterMap.entries.where((entry) {
      final value = entry.value;

      if (value is! Map) return false;

      final status = value['bookingStatus']?.toString() ??
          RideService.bookingStatusActive;

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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: RideService().streamRide(rideId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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

          final ride = snapshot.data!.data() ?? <String, dynamic>{};

          final String originName = _safeText(
            ride[RideService.fieldOriginName],
            'Origin',
          );

          final String destinationName = _safeText(
            ride[RideService.fieldDestinationName],
            'Destination',
          );

          final String departureRange = _formatDepartureRange(
            ride[RideService.fieldEarliestDeparture],
            ride[RideService.fieldLatestDeparture],
          );

          final String rideStatus =
              ride[RideService.fieldStatus]?.toString() ??
                  RideService.statusActive;

          final bool isExpired = _isActiveExpiredRide(ride, rideStatus);
          final bool isTerminal = _isTerminalStatus(rideStatus) || isExpired;
          final bool isInProgress = _isInProgressStatus(rideStatus);

          final passengers = _activePassengersFromRide(ride);

          final int availableSeats = ride[RideService.fieldAvailableSeats] is int
              ? ride[RideService.fieldAvailableSeats]
              : ride[RideService.fieldAvailableSeats] is num
              ? (ride[RideService.fieldAvailableSeats] as num).toInt()
              : 0;

          final int totalSeats = ride[RideService.fieldTotalSeats] is int
              ? ride[RideService.fieldTotalSeats]
              : ride[RideService.fieldTotalSeats] is num
              ? (ride[RideService.fieldTotalSeats] as num).toInt()
              : 0;

          final bool canEditRoster = rideStatus == RideService.statusActive &&
              !isExpired &&
              RideService().canCancelRideFromData(ride);

          final bool canUsePickupControls = isInProgress && !isTerminal;

          final String lockMessage = _rosterLockMessage(
            status: rideStatus,
            isExpired: isExpired,
            canEditRoster: canEditRoster,
          );

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
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.greyText,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            departureRange,
                            style: const TextStyle(
                              color: AppColors.greyText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Seats: $availableSeats/$totalSeats available',
                      style: const TextStyle(
                        color: AppColors.greyText,
                        fontSize: 13,
                      ),
                    ),
                    if (lockMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isTerminal
                              ? Colors.redAccent.withValues(alpha: 0.08)
                              : AppColors.navy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isTerminal
                                  ? Icons.lock_outline
                                  : Icons.info_outline,
                              color: isTerminal
                                  ? Colors.redAccent
                                  : AppColors.navy,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lockMessage,
                                style: TextStyle(
                                  color: isTerminal
                                      ? Colors.redAccent
                                      : AppColors.navy,
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
                        'No active riders in this roster.',
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
                    canRemove: canEditRoster,
                    canUsePickupControls: canUsePickupControls,
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
  final bool canUsePickupControls;
  final VoidCallback onRemove;

  const _PassengerCard({
    required this.rideId,
    required this.rideStatus,
    required this.passengerId,
    required this.passenger,
    required this.pickupLatLng,
    required this.canRemove,
    required this.canUsePickupControls,
    required this.onRemove,
  });

  @override
  State<_PassengerCard> createState() => _PassengerCardState();
}

class _PassengerCardState extends State<_PassengerCard> {
  bool _isMarkingArrived = false;
  bool _isMarkingNoShow = false;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMarkingArrived = false);
      }
    }
  }

  Future<void> _confirmMarkNoShow({
    required String riderName,
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Mark No-Show?',
            style: TextStyle(color: Colors.redAccent),
          ),
          content: Text(
            'Mark $riderName as no-show? They will be removed from the active roster, and you will be able to complete the ride without scanning them.',
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
              child: const Text('Mark No-Show'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;

    setState(() => _isMarkingNoShow = true);

    try {
      await RideService().markPassengerNoShow(
        rideId: widget.rideId,
        passengerId: widget.passengerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$riderName marked as no-show.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMarkingNoShow = false);
      }
    }
  }

  Future<void> _openScanner(BuildContext context) async {
    final status = await Permission.camera.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to scan QR codes.'),
          backgroundColor: Colors.redAccent,
        ),
      );

      return;
    }

    if (!context.mounted) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rider scanned and on board!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String riderName = _safeText(widget.passenger['riderName'], 'Rider');

    final String riderPhone = _safeText(
      widget.passenger['riderPhone'],
      'No phone',
    );

    final String riderImageUrl = _safeText(
      widget.passenger['riderImageUrl'],
      '',
    );

    final String pickupName = _safeText(
      widget.passenger['pickupName'],
      'Saved Home Location',
    );

    final bool isPickedUp =
        widget.passenger[RideService.bookingFieldIsPickedUp] == true;

    final bool driverArrived =
        widget.passenger[RideService.bookingFieldDriverArrivedAt] != null;

    final bool canMarkNoShow = widget.canUsePickupControls && !isPickedUp;

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
                    : widget.canUsePickupControls
                    ? 'Use Mark No-Show after the ride starts'
                    : 'Roster editing is locked for this ride',
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
          if (widget.canUsePickupControls) ...[
            const SizedBox(height: 10),
            if (isPickedUp)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF16A34A),
                      size: 18,
                    ),
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
            else ...[
              Row(
                children: [
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: canMarkNoShow && !_isMarkingNoShow
                      ? () => _confirmMarkNoShow(riderName: riderName)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                      color: canMarkNoShow
                          ? Colors.redAccent
                          : AppColors.greyText,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _isMarkingNoShow
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.redAccent,
                    ),
                  )
                      : const Icon(Icons.person_off_outlined, size: 18),
                  label: Text(
                    _isMarkingNoShow ? 'Marking...' : 'Mark No-Show',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
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

  const _TripStatusPanel({
    required this.rideId,
    required this.ride,
  });

  @override
  State<_TripStatusPanel> createState() => _TripStatusPanelState();
}

class _TripStatusPanelState extends State<_TripStatusPanel> {
  bool _isLoading = false;

  static const _stepLabels = [
    'Scheduled',
    'Started',
    'All Picked\nUp',
    'Completed',
  ];

  static const _stepIcons = [
    Icons.schedule,
    Icons.directions_car,
    Icons.people,
    Icons.check_circle,
  ];

  ({int total, int scanned}) _pickupProgress() {
    final dynamic roster = widget.ride[RideService.fieldPassengerRoster];

    if (roster is! Map) {
      return (total: 0, scanned: 0);
    }

    final rosterMap = Map<String, dynamic>.from(roster);

    final active = rosterMap.values.where((booking) {
      if (booking is! Map) return false;

      return (booking['bookingStatus']?.toString() ??
          RideService.bookingStatusActive) ==
          RideService.bookingStatusActive;
    }).toList();

    final scanned = active.where((booking) {
      return (booking as Map)[RideService.bookingFieldIsPickedUp] == true;
    }).length;

    return (total: active.length, scanned: scanned);
  }

  bool _isInProgressStatus(String status) {
    return status == RideService.statusStarted ||
        status == RideService.statusArrivedAtPickup;
  }

  bool _isActiveExpiredRide(String status) {
    return status == RideService.statusActive &&
        RideService().isRideExpired(widget.ride);
  }

  Color _statusColor({
    required String status,
    required bool isExpired,
    required bool allScanned,
  }) {
    if (status == RideService.statusCancelled) return Colors.redAccent;
    if (status == RideService.statusCompleted) return const Color(0xFF16A34A);
    if (isExpired) return Colors.orange;

    if (_isInProgressStatus(status) && allScanned) {
      return const Color(0xFF16A34A);
    }

    if (_isInProgressStatus(status)) return const Color(0xFF2563EB);

    return AppColors.navy;
  }

  String _statusTitle({
    required String status,
    required bool isExpired,
    required bool allScanned,
  }) {
    if (status == RideService.statusCancelled) return 'Cancelled';
    if (status == RideService.statusCompleted) return 'Completed';
    if (isExpired) return 'Expired';
    if (_isInProgressStatus(status) && allScanned) return 'All Riders Picked Up';
    if (_isInProgressStatus(status)) return 'Ride Started';

    return 'Scheduled';
  }

  String _statusDescription({
    required String status,
    required bool isExpired,
    required int total,
    required int scanned,
    required bool allScanned,
  }) {
    if (status == RideService.statusCancelled) {
      return 'This ride has been cancelled. The roster is now read-only.';
    }

    if (status == RideService.statusCompleted) {
      return 'This ride is completed. No further changes can be made.';
    }

    if (isExpired) {
      return 'This ride expired before it was started. You can remove it from history from My Rides.';
    }

    if (_isInProgressStatus(status) && allScanned) {
      return 'All active riders are handled. You can now complete the ride.';
    }

    if (_isInProgressStatus(status)) {
      return '$scanned/$total active riders scanned. Scan riders who boarded or mark missing riders as no-show.';
    }

    return 'This ride is scheduled and ready to start.';
  }

  Future<void> _advanceStatus(String currentStatus) async {
    final bool isExpired = _isActiveExpiredRide(currentStatus);

    if (isExpired ||
        currentStatus == RideService.statusCancelled ||
        currentStatus == RideService.statusCompleted) {
      return;
    }

    String next;
    String confirmMessage;
    String buttonLabel;
    Color buttonColor;

    if (currentStatus == RideService.statusActive) {
      next = RideService.statusStarted;
      confirmMessage = 'Start the ride?';
      buttonLabel = 'Start Ride';
      buttonColor = const Color(0xFF2563EB);
    } else if (_isInProgressStatus(currentStatus)) {
      next = RideService.statusCompleted;
      confirmMessage =
      'Mark this ride as completed? Make sure all missing riders are marked no-show first. This cannot be undone.';
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.greyText),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated: $buttonLabel'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildAlignedStepper({
    required int currentStepIndex,
    required Color activeColor,
    required bool isCancelled,
  }) {
    return Column(
      children: [
        SizedBox(
          height: 42,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double circleSize = 34;
              const double horizontalPadding = circleSize / 2;

              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    top: 20,
                    child: Row(
                      children: List.generate(_stepLabels.length - 1, (index) {
                        final bool isLineDone =
                            currentStepIndex > index && !isCancelled;

                        return Expanded(
                          child: Container(
                            height: 2,
                            color: isLineDone
                                ? activeColor
                                : const Color(0xFFCBD5E1),
                          ),
                        );
                      }),
                    ),
                  ),
                  Row(
                    children: List.generate(_stepLabels.length, (index) {
                      final bool isDone =
                          currentStepIndex >= index && !isCancelled;

                      return Expanded(
                        child: Center(
                          child: Container(
                            width: circleSize,
                            height: circleSize,
                            decoration: BoxDecoration(
                              color: isDone ? activeColor : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDone
                                    ? activeColor
                                    : const Color(0xFFCBD5E1),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _stepIcons[index],
                              size: 17,
                              color: isDone
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_stepLabels.length, (index) {
            final bool isDone = currentStepIndex >= index && !isCancelled;

            return Expanded(
              child: Text(
                _stepLabels[index],
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  height: 1.05,
                  fontSize: 10,
                  fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                  color: isDone ? AppColors.black : AppColors.greyText,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String status =
        widget.ride[RideService.fieldStatus]?.toString() ??
            RideService.statusActive;

    final progress = _pickupProgress();

    final bool isCancelled = status == RideService.statusCancelled;
    final bool isCompleted = status == RideService.statusCompleted;
    final bool isExpired = _isActiveExpiredRide(status);
    final bool isInProgress = _isInProgressStatus(status);
    final bool isTerminal = isCompleted || isCancelled || isExpired;

    final bool allScanned =
        progress.total == 0 || progress.scanned == progress.total;

    final int currentStepIndex = isCompleted
        ? 3
        : isInProgress && allScanned
        ? 2
        : isInProgress
        ? 1
        : 0;

    final Color statusColor = _statusColor(
      status: status,
      isExpired: isExpired,
      allScanned: allScanned,
    );

    final String statusTitle = _statusTitle(
      status: status,
      isExpired: isExpired,
      allScanned: allScanned,
    );

    final String statusDescription = _statusDescription(
      status: status,
      isExpired: isExpired,
      total: progress.total,
      scanned: progress.scanned,
      allScanned: allScanned,
    );

    final bool canPressMainButton =
        !_isLoading &&
            !isTerminal &&
            !(isInProgress && !allScanned);

    String buttonText;
    IconData buttonIcon;
    Color buttonColor;

    if (status == RideService.statusActive && !isExpired) {
      buttonText = 'Start Ride';
      buttonIcon = Icons.play_arrow_rounded;
      buttonColor = const Color(0xFF2563EB);
    } else if (isInProgress && allScanned) {
      buttonText = 'Complete Ride';
      buttonIcon = Icons.check_circle_outline;
      buttonColor = const Color(0xFF16A34A);
    } else if (isInProgress && !allScanned) {
      buttonText = 'Scan or Mark No-Show';
      buttonIcon = Icons.person_off_outlined;
      buttonColor = AppColors.greyText;
    } else if (isExpired) {
      buttonText = 'Ride Expired';
      buttonIcon = Icons.timer_off_outlined;
      buttonColor = Colors.orange;
    } else if (isCancelled) {
      buttonText = 'Ride Cancelled';
      buttonIcon = Icons.cancel_outlined;
      buttonColor = Colors.redAccent;
    } else {
      buttonText = 'Ride Completed';
      buttonIcon = Icons.check_circle_outline;
      buttonColor = const Color(0xFF16A34A);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.18),
        ),
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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isExpired
                      ? Icons.timer_off_outlined
                      : isCancelled
                      ? Icons.cancel_outlined
                      : isCompleted
                      ? Icons.check_circle_outline
                      : isInProgress
                      ? Icons.directions_car
                      : Icons.schedule,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusTitle,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            statusDescription,
            style: const TextStyle(
              color: AppColors.greyText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _buildAlignedStepper(
            currentStepIndex: currentStepIndex,
            activeColor: statusColor,
            isCancelled: isCancelled,
          ),
          if (isInProgress && progress.total > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: allScanned
                    ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                    : const Color(0xFFD97706).withValues(alpha: 0.08),
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
                  Expanded(
                    child: Text(
                      allScanned
                          ? 'All active riders handled — ready to complete'
                          : '${progress.scanned}/${progress.total} active riders scanned',
                      style: TextStyle(
                        color: allScanned
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD97706),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed:
              canPressMainButton ? () => _advanceStatus(status) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: buttonColor.withValues(alpha: 0.55),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Icon(buttonIcon, size: 20),
              label: Text(
                _isLoading ? 'Updating...' : buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}