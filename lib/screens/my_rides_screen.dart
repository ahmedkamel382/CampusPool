import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_colors.dart';
import '../services/ride_service.dart';
import '../widgets/rating_dialog.dart';
import 'driver_roster_screen.dart';

class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({super.key});

  String _safeText(dynamic value, String fallback) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) return fallback;

    return text;
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return 'Not set';

    if (value is Timestamp) {
      final dateTime = value.toDate();
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '$displayHour:$minute $period';
    }

    return value.toString();
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
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _showQrDialog({
    required BuildContext context,
    required String rideId,
  }) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final String qrData = 'campuspool:$rideId:$uid';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your Boarding Pass',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Show this to your driver at pickup',
                style: TextStyle(color: AppColors.greyText, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.navy, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancelBooking({
    required BuildContext context,
    required String rideId,
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Booking?'),
          content: const Text(
            'Are you sure you want to cancel your booking for this ride?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'No',
                style: TextStyle(color: AppColors.greyText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel Booking'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!context.mounted) return;
    _showLoadingDialog(context, 'Cancelling booking...');

    try {
      await RideService().cancelMyBooking(rideId: rideId);

      if (context.mounted) {
        _closeLoadingDialog(context);
        _showMessage(
          context,
          message: 'Booking cancelled successfully.',
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

  Future<void> _confirmCancelRide({
    required BuildContext context,
    required String rideId,
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Cancel Ride?',
            style: TextStyle(color: Colors.redAccent),
          ),
          content: const Text(
            'Are you sure you want to cancel this ride? It will be removed from the Home feed and all active riders will be cancelled.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'No',
                style: TextStyle(color: AppColors.greyText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel Ride'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!context.mounted) return;
    _showLoadingDialog(context, 'Cancelling ride...');

    try {
      await RideService().cancelMyRide(rideId: rideId);

      if (context.mounted) {
        _closeLoadingDialog(context);
        _showMessage(
          context,
          message: 'Ride cancelled successfully.',
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

  Future<void> _confirmRemoveFromHistory({
    required BuildContext context,
    required String rideId,
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove from History?'),
          content: const Text(
            'This ride will be hidden from your history. It will not affect other users.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'No',
                style: TextStyle(color: AppColors.greyText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
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
    _showLoadingDialog(context, 'Removing from history...');

    try {
      await RideService().removeRideFromMyHistory(rideId: rideId);

      if (context.mounted) {
        _closeLoadingDialog(context);
        _showMessage(
          context,
          message: 'Ride removed from history.',
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _myBookedRidesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('rides')
        .where('passengerIds', arrayContains: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myDrivingRidesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('rides')
        .where('driverId', isEqualTo: uid)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _removeHiddenRides(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return docs;

    return docs.where((doc) {
      final data = doc.data();
      final hiddenList = List<String>.from(
        data[RideService.fieldHiddenFromHistoryFor] ?? [],
      );

      return !hiddenList.contains(uid);
    }).toList();
  }

  void _openDriverRoster({
    required BuildContext context,
    required String rideId,
    required Map<String, dynamic> rideData,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverRosterScreen(
          rideId: rideId,
          rideData: rideData,
        ),
      ),
    );
  }

  Color _statusColor(String status, bool isExpired) {
    if (status == RideService.statusCompleted) return Colors.green;
    if (status == RideService.statusCancelled) return Colors.redAccent;
    if (status == RideService.statusStarted) return const Color(0xFF2563EB);
    if (status == RideService.statusArrivedAtPickup) return const Color(0xFFD97706);
    if (isExpired) return Colors.orange;
    if (status == RideService.statusActive) return Colors.blue;
    return Colors.grey;
  }

  String _statusLabel(String status, bool isExpired) {
    if (status == RideService.statusCompleted) return 'Completed';
    if (status == RideService.statusCancelled) return 'Cancelled';
    if (status == RideService.statusStarted) return 'In Progress';
    if (status == RideService.statusArrivedAtPickup) return 'At Pickup';
    if (isExpired) return 'Expired';
    if (status == RideService.statusActive) return 'Upcoming';
    return 'In Progress';
  }

  int _rideSortPriority(Map<String, dynamic> ride) {
    final String status = _safeText(
      ride[RideService.fieldStatus],
      RideService.statusActive,
    );

    final bool isExpired = RideService().isRideExpired(ride);

    if (status == RideService.statusArrivedAtPickup) return 0;
    if (status == RideService.statusStarted) return 1;
    if (status == RideService.statusActive && !isExpired) return 2;
    if (status == RideService.statusCompleted) return 3;
    if (isExpired) return 4;
    if (status == RideService.statusCancelled) return 5;

    return 6;
  }

  int _compareRideDocs(
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b,
      ) {
    final rideA = a.data();
    final rideB = b.data();

    final int priorityA = _rideSortPriority(rideA);
    final int priorityB = _rideSortPriority(rideB);

    if (priorityA != priorityB) {
      return priorityA.compareTo(priorityB);
    }

    final timeA = RideService().getEarliestDepartureDateTime(rideA);
    final timeB = RideService().getEarliestDepartureDateTime(rideB);

    if (timeA == null && timeB == null) return 0;
    if (timeA == null) return 1;
    if (timeB == null) return -1;

    if (priorityA == 0) {
      return timeA.compareTo(timeB);
    }

    return timeB.compareTo(timeA);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'My Rides',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.navy,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.greyText,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Riding'),
              Tab(text: 'Driving'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const BouncingScrollPhysics(),
          children: [
            _buildRidingTab(),
            _buildDrivingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRidingTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myBookedRidesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.navy),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final docs = _removeHiddenRides(allDocs);

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No booked rides found.',
              style: TextStyle(color: AppColors.greyText),
            ),
          );
        }

        final sortedDocs =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

        sortedDocs.sort(_compareRideDocs);

        return ListView.separated(
          padding: const EdgeInsets.all(24.0),
          itemCount: sortedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];

            return _buildRidingCard(
              context: context,
              rideId: doc.id,
              ride: doc.data(),
            );
          },
        );
      },
    );
  }

  Widget _buildDrivingTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myDrivingRidesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.navy),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final docs = _removeHiddenRides(allDocs);

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No driving rides found.',
              style: TextStyle(color: AppColors.greyText),
            ),
          );
        }

        final sortedDocs =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

        sortedDocs.sort(_compareRideDocs);

        return ListView.separated(
          padding: const EdgeInsets.all(24.0),
          itemCount: sortedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];

            return _buildDrivingCard(
              context: context,
              rideId: doc.id,
              ride: doc.data(),
            );
          },
        );
      },
    );
  }

  Widget _buildRidingCard({
    required BuildContext context,
    required String rideId,
    required Map<String, dynamic> ride,
  }) {
    final String driverName = _safeText(
      ride[RideService.fieldDriverName],
      'Driver',
    );

    final String driverPhone = _safeText(
      ride[RideService.fieldDriverPhone],
      'No phone number',
    );

    final String originName = _safeText(
      ride[RideService.fieldOriginName],
      'Origin',
    );

    final String destinationName = _safeText(
      ride[RideService.fieldDestinationName],
      'Destination',
    );

    final String earliestDeparture = _formatTimestamp(
      ride[RideService.fieldEarliestDeparture],
    );

    final String latestDeparture = _formatTimestamp(
      ride[RideService.fieldLatestDeparture],
    );

    final String price = _safeText(
      ride[RideService.fieldPrice],
      '0',
    );

    final String status = _safeText(
      ride[RideService.fieldStatus],
      RideService.statusActive,
    );

    final bool isExpired = RideService().isRideExpired(ride);

    final bool isInProgress = status == RideService.statusStarted ||
        status == RideService.statusArrivedAtPickup;

    // Check if the driver has marked arrival at THIS rider's pickup specifically
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final dynamic roster = ride[RideService.fieldPassengerRoster];
    final dynamic myBooking =
    (roster is Map && uid != null) ? roster[uid] : null;
    final bool driverArrivedAtMe = myBooking is Map &&
        myBooking[RideService.bookingFieldDriverArrivedAt] != null;
    final bool isScanned = myBooking is Map &&
        myBooking[RideService.bookingFieldIsPickedUp] == true;

    final bool isCompleted = status == RideService.statusCompleted;
    final bool hasRated = uid != null &&
        RideService().hasAlreadyRated(ride, uid);
    final String driverId = _safeText(
      ride[RideService.fieldDriverId],
      '',
    );

    final bool canCancel =
        status == RideService.statusActive &&
            !isExpired &&
            RideService().canCancelRideFromData(ride);

    final String badgeText = _statusLabel(status, isExpired);
    final Color badgeColor = _statusColor(status, isExpired);

    // Auto-show rating dialog once when ride completes and hasn't been rated
    if (isCompleted && !hasRated && driverId.isNotEmpty && uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          RatingDialog.show(
            context: context,
            rideId: rideId,
            driverUid: driverId,
            driverName: driverName,
          );
        }
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: const Color(0xFFF0F2F5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_seat, color: AppColors.navy, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$originName → $destinationName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha:0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Driver: $driverName',
            style: const TextStyle(
              color: AppColors.greyText,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 4),

          GestureDetector(
            onTap: driverPhone == 'No phone number'
                ? null
                : () => _openWhatsApp(driverPhone),
            child: Row(
              children: [
                const Icon(Icons.chat, color: Color(0xFF25D366), size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    driverPhone == 'No phone number'
                        ? 'No phone number'
                        : '$driverPhone · Tap to WhatsApp',
                    style: TextStyle(
                      color: driverPhone == 'No phone number'
                          ? AppColors.greyText
                          : const Color(0xFF25D366),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '$earliestDeparture - $latestDeparture',
            style: const TextStyle(
              color: AppColors.greyText,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$price EGP',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: isInProgress
                ? Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: isScanned
                    ? const Color(0xFF2563EB).withValues(alpha:0.08)
                    : driverArrivedAtMe
                    ? const Color(0xFFD97706).withValues(alpha:0.10)
                    : _statusColor(status, isExpired).withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isScanned
                        ? Icons.directions_car
                        : driverArrivedAtMe
                        ? Icons.location_on
                        : Icons.directions_car,
                    color: isScanned
                        ? const Color(0xFF2563EB)
                        : driverArrivedAtMe
                        ? const Color(0xFFD97706)
                        : _statusColor(status, isExpired),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isScanned
                        ? 'Ride in progress'
                        : driverArrivedAtMe
                        ? 'Driver has arrived at your pickup!'
                        : 'Driver is on the way',
                    style: TextStyle(
                      color: isScanned
                          ? const Color(0xFF2563EB)
                          : driverArrivedAtMe
                          ? const Color(0xFFD97706)
                          : _statusColor(status, isExpired),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
                : OutlinedButton.icon(
              onPressed: canCancel
                  ? () => _confirmCancelBooking(
                context: context,
                rideId: rideId,
              )
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor:
                canCancel ? Colors.redAccent : AppColors.greyText,
                side: BorderSide(
                  color:
                  canCancel ? Colors.redAccent : AppColors.greyText,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(
                canCancel ? Icons.cancel_outlined : Icons.lock_outline,
                size: 18,
              ),
              label: Text(
                canCancel ? 'Cancel Booking' : 'Cancellation Locked',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Always-visible QR boarding pass button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showQrDialog(
                context: context,
                rideId: rideId,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.navy),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: const Text(
                'Show Boarding Pass',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Rate Driver button — only on completed unrated rides
          if (isCompleted && !hasRated && driverId.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => RatingDialog.show(
                  context: context,
                  rideId: rideId,
                  driverUid: driverId,
                  driverName: driverName,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.star, size: 18),
                label: const Text(
                  'Rate Driver',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          if (isCompleted && hasRated) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: AppColors.gold, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Driver rated — thank you!',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrivingCard({
    required BuildContext context,
    required String rideId,
    required Map<String, dynamic> ride,
  }) {
    final String originName = _safeText(
      ride[RideService.fieldOriginName],
      'Origin',
    );

    final String destinationName = _safeText(
      ride[RideService.fieldDestinationName],
      'Destination',
    );

    final String earliestDeparture = _formatTimestamp(
      ride[RideService.fieldEarliestDeparture],
    );

    final String latestDeparture = _formatTimestamp(
      ride[RideService.fieldLatestDeparture],
    );

    final String price = _safeText(
      ride[RideService.fieldPrice],
      '0',
    );

    final String status = _safeText(
      ride[RideService.fieldStatus],
      RideService.statusActive,
    );

    final bool isExpired = RideService().isRideExpired(ride);

    // Rides that are in-progress are still "active" from a UI perspective
    final bool isInProgress = status == RideService.statusStarted ||
        status == RideService.statusArrivedAtPickup;

    final bool isNotActiveOrExpired =
        !isInProgress && (status != RideService.statusActive || isExpired);

    final bool canCancel =
        status == RideService.statusActive &&
            !isExpired &&
            RideService().canCancelRideFromData(ride);

    final String badgeText = _statusLabel(status, isExpired);
    final Color badgeColor = _statusColor(status, isExpired);

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

    final int bookedSeats = totalSeats - availableSeats;

    String buttonText;
    IconData buttonIcon;
    Color buttonColor;
    VoidCallback? buttonAction;

    if (isNotActiveOrExpired) {
      buttonText = 'Remove from History';
      buttonIcon = Icons.history_toggle_off;
      buttonColor = AppColors.navy;
      buttonAction = () => _confirmRemoveFromHistory(
        context: context,
        rideId: rideId,
      );
    } else if (canCancel) {
      buttonText = 'Cancel Ride';
      buttonIcon = Icons.cancel_outlined;
      buttonColor = Colors.redAccent;
      buttonAction = () => _confirmCancelRide(
        context: context,
        rideId: rideId,
      );
    } else {
      buttonText = 'Cancellation Locked';
      buttonIcon = Icons.lock_outline;
      buttonColor = AppColors.greyText;
      buttonAction = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: const Color(0xFFF0F2F5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _openDriverRoster(
              context: context,
              rideId: rideId,
              rideData: ride,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_car,
                  color: AppColors.navy,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$originName → $destinationName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$earliestDeparture - $latestDeparture',
                        style: const TextStyle(
                          color: AppColors.greyText,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$availableSeats/$totalSeats seats available • $bookedSeats booked',
                        style: const TextStyle(
                          color: AppColors.greyText,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to view roster',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha:0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Driver',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$price EGP',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: buttonAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: buttonColor,
                side: BorderSide(color: buttonColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(buttonIcon, size: 18),
              label: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
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