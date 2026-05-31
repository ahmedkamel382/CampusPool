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

  DateTime? _dateTimeFromDynamic(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

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

  String _formatTimestamp(dynamic value) {
    final DateTime? dateTime = _dateTimeFromDynamic(value);

    if (dateTime == null) {
      if (value == null) return 'Not set';
      return value.toString();
    }

    return '${_formatShortDate(dateTime)} • ${_formatTimeOnly(dateTime)}';
  }

  String _formatDepartureRange(dynamic earliestValue, dynamic latestValue) {
    final DateTime? earliest = _dateTimeFromDynamic(earliestValue);
    final DateTime? latest = _dateTimeFromDynamic(latestValue);

    if (earliest == null && latest == null) {
      return 'Not set';
    }

    if (earliest == null) {
      return _formatTimestamp(latestValue);
    }

    if (latest == null) {
      return _formatTimestamp(earliestValue);
    }

    final bool sameDate = earliest.year == latest.year &&
        earliest.month == latest.month &&
        earliest.day == latest.day;

    if (sameDate) {
      return '${_formatShortDate(earliest)} • ${_formatTimeOnly(earliest)} - ${_formatTimeOnly(latest)}';
    }

    return '${_formatShortDate(earliest)} • ${_formatTimeOnly(earliest)} - ${_formatShortDate(latest)} • ${_formatTimeOnly(latest)}';
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
    return FirebaseFirestore.instance.collection('rides').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myDrivingRidesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('rides')
        .where(RideService.fieldDriverId, isEqualTo: uid)
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterRidingHistory(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return [];

    return docs.where((doc) {
      final ride = doc.data();

      final List<String> passengerIds =
          (ride[RideService.fieldPassengerIds] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
              <String>[];

      final dynamic roster = ride[RideService.fieldPassengerRoster];

      final bool existsInRoster = roster is Map && roster.containsKey(uid);
      final bool existsInPassengerIds = passengerIds.contains(uid);

      return existsInRoster || existsInPassengerIds;
    }).toList();
  }

  Map<String, dynamic>? _myBookingFromRide(Map<String, dynamic> ride) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return null;

    final dynamic roster = ride[RideService.fieldPassengerRoster];

    if (roster is Map && roster[uid] is Map) {
      return Map<String, dynamic>.from(roster[uid]);
    }

    return null;
  }

  String _myBookingStatus(Map<String, dynamic> ride) {
    final booking = _myBookingFromRide(ride);

    return booking?['bookingStatus']?.toString() ??
        RideService.bookingStatusActive;
  }

  bool _isMyBookingActive(Map<String, dynamic> ride) {
    return _myBookingStatus(ride) == RideService.bookingStatusActive;
  }

  String _ridingStatusLabel({
    required Map<String, dynamic> ride,
    required String rideStatus,
    required bool isPast,
  }) {
    final String bookingStatus = _myBookingStatus(ride);

    if (bookingStatus == RideService.bookingStatusCancelled) {
      return 'Booking Cancelled';
    }

    if (bookingStatus == RideService.bookingStatusRemoved) {
      return 'Removed / No-Show';
    }

    return _statusLabel(
      status: rideStatus,
      isPast: isPast,
    );
  }

  Color _ridingStatusColor({
    required Map<String, dynamic> ride,
    required String rideStatus,
    required bool isPast,
  }) {
    final String bookingStatus = _myBookingStatus(ride);

    if (bookingStatus == RideService.bookingStatusCancelled) {
      return Colors.redAccent;
    }

    if (bookingStatus == RideService.bookingStatusRemoved) {
      return Colors.orange;
    }

    return _statusColor(
      status: rideStatus,
      isPast: isPast,
    );
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

  bool _isPastRide(Map<String, dynamic> ride) {
    final String status = _safeText(
      ride[RideService.fieldStatus],
      RideService.statusActive,
    );

    if (status == RideService.statusCompleted) {
      return true;
    }

    return RideService().isRideExpired(ride);
  }

  bool _isRideCancelled(Map<String, dynamic> ride) {
    final String status = _safeText(
      ride[RideService.fieldStatus],
      RideService.statusActive,
    );

    return status == RideService.statusCancelled;
  }

  bool _isMyRidingBookingCancelledOrRemoved(Map<String, dynamic> ride) {
    final String bookingStatus = _myBookingStatus(ride);

    return bookingStatus == RideService.bookingStatusCancelled ||
        bookingStatus == RideService.bookingStatusRemoved;
  }

  DateTime? _rideSortTime(Map<String, dynamic> ride) {
    return RideService().getEarliestDepartureDateTime(ride);
  }

  int _compareFutureTimesAscending(
      Map<String, dynamic> rideA,
      Map<String, dynamic> rideB,
      ) {
    final DateTime? timeA = _rideSortTime(rideA);
    final DateTime? timeB = _rideSortTime(rideB);

    if (timeA == null && timeB == null) return 0;
    if (timeA == null) return 1;
    if (timeB == null) return -1;

    return timeA.compareTo(timeB);
  }

  int _comparePastTimesDescending(
      Map<String, dynamic> rideA,
      Map<String, dynamic> rideB,
      ) {
    final DateTime? timeA = _rideSortTime(rideA);
    final DateTime? timeB = _rideSortTime(rideB);

    if (timeA == null && timeB == null) return 0;
    if (timeA == null) return 1;
    if (timeB == null) return -1;

    return timeB.compareTo(timeA);
  }

  int _drivingSortGroup(Map<String, dynamic> ride) {
    final bool isPast = _isPastRide(ride);
    final bool isCancelled = _isRideCancelled(ride);

    // 0 = active upcoming / active in-progress rides
    if (!isPast && !isCancelled) {
      return 0;
    }

    // 1 = cancelled ride, but its date/time has not passed yet
    if (!isPast && isCancelled) {
      return 1;
    }

    // 2 = past/history rides, newest first, no matter status
    return 2;
  }

  int _ridingSortGroup(Map<String, dynamic> ride) {
    final bool isPast = _isPastRide(ride);
    final bool rideCancelled = _isRideCancelled(ride);
    final bool myBookingCancelledOrRemoved =
    _isMyRidingBookingCancelledOrRemoved(ride);

    // 0 = active upcoming / in-progress rides where my booking is active
    if (!isPast && !rideCancelled && !myBookingCancelledOrRemoved) {
      return 0;
    }

    // 1 = cancelled / removed / no-show, but ride time is still upcoming
    if (!isPast) {
      return 1;
    }

    // 2 = past/history rides, newest first, no matter status
    return 2;
  }

  int _compareRideDocs(
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b,
      ) {
    final Map<String, dynamic> rideA = a.data();
    final Map<String, dynamic> rideB = b.data();

    final int groupA = _drivingSortGroup(rideA);
    final int groupB = _drivingSortGroup(rideB);

    if (groupA != groupB) {
      return groupA.compareTo(groupB);
    }

    if (groupA == 0 || groupA == 1) {
      return _compareFutureTimesAscending(rideA, rideB);
    }

    return _comparePastTimesDescending(rideA, rideB);
  }

  int _compareRidingRideDocs(
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b,
      ) {
    final Map<String, dynamic> rideA = a.data();
    final Map<String, dynamic> rideB = b.data();

    final int groupA = _ridingSortGroup(rideA);
    final int groupB = _ridingSortGroup(rideB);

    if (groupA != groupB) {
      return groupA.compareTo(groupB);
    }

    if (groupA == 0 || groupA == 1) {
      return _compareFutureTimesAscending(rideA, rideB);
    }

    return _comparePastTimesDescending(rideA, rideB);
  }

  Color _statusColor({
    required String status,
    required bool isPast,
  }) {
    if (status == RideService.statusCompleted) return Colors.green;
    if (status == RideService.statusCancelled) return Colors.redAccent;
    if (status == RideService.statusStarted) return const Color(0xFF2563EB);

    if (status == RideService.statusArrivedAtPickup) {
      return const Color(0xFFD97706);
    }

    if (isPast) return Colors.orange;
    if (status == RideService.statusActive) return Colors.blue;

    return Colors.grey;
  }

  String _statusLabel({
    required String status,
    required bool isPast,
  }) {
    if (status == RideService.statusCompleted) return 'Completed';
    if (status == RideService.statusCancelled) return 'Cancelled';
    if (status == RideService.statusStarted) return 'In Progress';
    if (status == RideService.statusArrivedAtPickup) return 'At Pickup';
    if (isPast) return 'Expired';
    if (status == RideService.statusActive) return 'Upcoming';

    return 'In Progress';
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
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.navy),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final visibleDocs = _removeHiddenRides(allDocs);
        final docs = _filterRidingHistory(visibleDocs);

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No Booked Rides Found.',
              style: TextStyle(color: AppColors.greyText),
            ),
          );
        }

        final sortedDocs =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

        sortedDocs.sort(_compareRidingRideDocs);

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
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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

    final String departureRange = _formatDepartureRange(
      ride[RideService.fieldEarliestDeparture],
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

    final bool isPast = _isPastRide(ride);
    final bool bookingIsActive = _isMyBookingActive(ride);

    final bool isInProgress = bookingIsActive &&
        (status == RideService.statusStarted ||
            status == RideService.statusArrivedAtPickup);

    final Map<String, dynamic>? myBooking = _myBookingFromRide(ride);

    final bool driverArrivedAtMe = myBooking != null &&
        myBooking[RideService.bookingFieldDriverArrivedAt] != null;

    final bool isScanned = myBooking != null &&
        myBooking[RideService.bookingFieldIsPickedUp] == true;

    final bool isCompleted =
        bookingIsActive && status == RideService.statusCompleted;

    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    final bool hasRated =
        uid != null && RideService().hasAlreadyRated(ride, uid);

    final String driverId = _safeText(
      ride[RideService.fieldDriverId],
      '',
    );

    final bool canCancel = bookingIsActive &&
        status == RideService.statusActive &&
        !isPast &&
        RideService().canCancelRideFromData(ride);

    final String badgeText = _ridingStatusLabel(
      ride: ride,
      rideStatus: status,
      isPast: isPast,
    );

    final Color badgeColor = _ridingStatusColor(
      ride: ride,
      rideStatus: status,
      isPast: isPast,
    );

    final bool canShowQr = bookingIsActive &&
        !isPast &&
        (status == RideService.statusActive ||
            status == RideService.statusStarted ||
            status == RideService.statusArrivedAtPickup);

    final bool shouldShowRemoveFromHistory =
        !bookingIsActive ||
            status == RideService.statusCancelled ||
            isPast ||
            status == RideService.statusCompleted;

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
            departureRange,
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
          if (isInProgress)
            Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: isScanned
                    ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                    : driverArrivedAtMe
                    ? const Color(0xFFD97706).withValues(alpha: 0.10)
                    : _statusColor(
                  status: status,
                  isPast: isPast,
                ).withValues(alpha: 0.08),
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
                        : _statusColor(
                      status: status,
                      isPast: isPast,
                    ),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isScanned
                        ? 'Ride in Progress'
                        : driverArrivedAtMe
                        ? 'Driver Has Arrived At Your Pickup!'
                        : 'Driver is On The Way',
                    style: TextStyle(
                      color: isScanned
                          ? const Color(0xFF2563EB)
                          : driverArrivedAtMe
                          ? const Color(0xFFD97706)
                          : _statusColor(
                        status: status,
                        isPast: isPast,
                      ),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else if (canCancel)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _confirmCancelBooking(
                  context: context,
                  rideId: rideId,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text(
                  'Cancel Booking',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          else if (shouldShowRemoveFromHistory)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmRemoveFromHistory(
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
                  icon: const Icon(Icons.history_toggle_off, size: 18),
                  label: const Text(
                    'Remove from History',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.greyText,
                    side: const BorderSide(color: AppColors.greyText),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text(
                    'Cancellation Locked',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          if (canShowQr) ...[
            const SizedBox(height: 10),
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
          ],
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
                color: AppColors.gold.withValues(alpha: 0.1),
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

    final String departureRange = _formatDepartureRange(
      ride[RideService.fieldEarliestDeparture],
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

    final bool isPast = _isPastRide(ride);

    final bool isInProgress = status == RideService.statusStarted ||
        status == RideService.statusArrivedAtPickup;

    final bool isNotActiveOrPast =
        !isInProgress && (status != RideService.statusActive || isPast);

    final bool canCancel = status == RideService.statusActive &&
        !isPast &&
        RideService().canCancelRideFromData(ride);

    final String badgeText = _statusLabel(
      status: status,
      isPast: isPast,
    );

    final Color badgeColor = _statusColor(
      status: status,
      isPast: isPast,
    );

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

    if (isNotActiveOrPast) {
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
                        departureRange,
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