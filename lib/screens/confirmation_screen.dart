import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_colors.dart';
import '../widgets/custom_buttons.dart';

class ConfirmationScreen extends StatefulWidget {
  final String rideId;
  final String? riderId;
  final Map<String, dynamic> rideData;
  final String? pickupName;

  const ConfirmationScreen({
    super.key,
    required this.rideId,
    required this.rideData,
    this.riderId,
    this.pickupName,
  });

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  String _finalPickupName = 'Saved Home Location';
  bool _isLoadingPickup = true;

  @override
  void initState() {
    super.initState();
    _loadPickupName();
  }

  Future<void> _loadPickupName() async {
    if (widget.pickupName != null && widget.pickupName!.trim().isNotEmpty) {
      setState(() {
        _finalPickupName = widget.pickupName!.trim();
        _isLoadingPickup = false;
      });
      return;
    }

    final String? currentRiderId =
        widget.riderId ?? FirebaseAuth.instance.currentUser?.uid;

    if (currentRiderId == null) {
      setState(() {
        _finalPickupName = 'Saved Home Location';
        _isLoadingPickup = false;
      });
      return;
    }

    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();

      if (!mounted) return;

      if (rideDoc.exists && rideDoc.data() != null) {
        final data = rideDoc.data()!;
        final roster = data['passengerRoster'];

        if (roster is Map && roster[currentRiderId] is Map) {
          final riderBooking = Map<String, dynamic>.from(roster[currentRiderId]);
          final pickup = riderBooking['pickupName']?.toString().trim();

          setState(() {
            _finalPickupName =
            (pickup != null && pickup.isNotEmpty) ? pickup : 'Saved Home Location';
            _isLoadingPickup = false;
          });
          return;
        }
      }

      setState(() {
        _finalPickupName = 'Saved Home Location';
        _isLoadingPickup = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _finalPickupName = 'Saved Home Location';
        _isLoadingPickup = false;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final ride = widget.rideData;

    final String driverName = _safeText(ride['driverName'], 'Driver');

    final String earliestDeparture =
    _formatTimestamp(ride['earliestDeparture']);
    final String latestDeparture =
    _formatTimestamp(ride['latestDeparture']);

    final String price = _safeText(ride['price'], '0');

    final Map<String, dynamic> carInfo = ride['carInfo'] is Map
        ? Map<String, dynamic>.from(ride['carInfo'])
        : <String, dynamic>{};

    final String carMake = _safeText(carInfo['make'], 'Car');
    final String carModel = _safeText(carInfo['model'], '');
    final String carColor = _safeText(carInfo['color'], 'Color not set');
    final String carPlate = _safeText(carInfo['plate'], 'Plate not set');

    final String fullCarTitle = '$carColor $carMake $carModel'.trim();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Booking Confirmed!',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Your ride has been successfully booked',
                style: TextStyle(
                  color: AppColors.greyText,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.navy,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Digital Ticket',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildRow('Driver:', driverName),

                    const SizedBox(height: 12),

                    _buildRow(
                      'Departure:',
                      '$earliestDeparture - $latestDeparture',
                    ),

                    const SizedBox(height: 12),

                    _buildRow(
                      'Pickup:',
                      _isLoadingPickup ? 'Loading pickup...' : _finalPickupName,
                    ),

                    const SizedBox(height: 12),

                    _buildRow(
                      'Car Details:',
                      fullCarTitle,
                    ),

                    const SizedBox(height: 12),

                    _buildRow('License Plate:', carPlate),

                    const SizedBox(height: 12),

                    _buildRow('Price:', '$price EGP'),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Divider(color: Color(0xFFE2E8F0)),
                    ),

                    Container(
                      width: 180,
                      height: 180,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: AppColors.navy,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: QrImageView(
                        data: 'campuspool:${widget.rideId}:${widget.riderId ?? FirebaseAuth.instance.currentUser?.uid ?? ''}',
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Show this ticket to your driver',
                      style: TextStyle(
                        color: AppColors.greyText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              CustomNavyButton(
                text: 'Back to Home',
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.navy,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.greyText,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}