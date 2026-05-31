import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_locations.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_buttons.dart';
import '../services/ride_service.dart';
import 'confirmation_screen.dart';
import '../services/location_service.dart';

class RideDetailsScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;
  final LatLng? customPickupLocation;
  final String? customPickupName;

  const RideDetailsScreen({
    super.key,
    required this.rideId,
    required this.rideData,
    this.customPickupLocation,
    this.customPickupName,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  bool _isBooking = false;
  String _driverPhone = 'Loading...';
  bool _isLoadingDriverPhone = true;

  Timer? _debounceTimer;

  LatLng? _riderSelectedPin;
  String? _riderNeighborhood;
  String? _currentUserGender;
  bool _isLoadingRiderData = true;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadDriverPhone();
    _loadRiderDefaultLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _showMessage({
    required String message,
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  String _safeText(dynamic value, String fallback) {
    if (value == null) return fallback;

    final text = value.toString().trim();
    if (text.isEmpty) return fallback;

    return text;
  }

  String _normalizeGender(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';

    if (text.startsWith('m')) return 'male';
    if (text.startsWith('f')) return 'female';

    return text;
  }

  bool _isCampusName(String name) {
    return AppLocations.campusCoordinates.containsKey(name);
  }

  bool _isRideLeavingCampus(Map<String, dynamic> ride) {
    final String originName = _safeText(
      ride[RideService.fieldOriginName],
      '',
    );

    final String destinationName = _safeText(
      ride[RideService.fieldDestinationName],
      '',
    );

    final bool originIsCampus = _isCampusName(originName);
    final bool destinationIsCampus = _isCampusName(destinationName);

    if (originIsCampus && !destinationIsCampus) return true;
    if (!originIsCampus && destinationIsCampus) return false;

    return true;
  }

  String _rideNeighborhoodName(Map<String, dynamic> ride) {
    final bool isLeavingCampus = _isRideLeavingCampus(ride);

    if (isLeavingCampus) {
      return _safeText(
        ride[RideService.fieldDestinationName],
        'Other',
      );
    }

    return _safeText(
      ride[RideService.fieldOriginName],
      'Other',
    );
  }

  LatLng? _locationFromMap(dynamic value) {
    return RideService().mapToLatLng(value);
  }

  LatLng? _driverReferencePin(Map<String, dynamic> ride) {
    final bool isLeavingCampus = _isRideLeavingCampus(ride);

    if (isLeavingCampus) {
      return _locationFromMap(ride[RideService.fieldDestinationLocation]) ??
          AppLocations.neighborhoodCoordinates[
          ride[RideService.fieldDestinationName]?.toString()];
    }

    return _locationFromMap(ride[RideService.fieldOriginLocation]) ??
        AppLocations.neighborhoodCoordinates[
        ride[RideService.fieldOriginName]?.toString()];
  }

  bool _isSameGenderOnly(Map<String, dynamic> ride) {
    return ride[RideService.fieldSameGenderOnly] == true;
  }

  String? _sameGenderBlockReason(Map<String, dynamic> ride) {
    if (!_isSameGenderOnly(ride)) return null;

    final String riderGender = _normalizeGender(_currentUserGender);
    final String driverGender = _normalizeGender(
      ride[RideService.fieldDriverGender],
    );

    if (riderGender.isEmpty || driverGender.isEmpty) {
      return 'This ride is Same Gender Only, but gender information is missing.';
    }

    if (riderGender != driverGender) {
      return 'This ride is restricted to riders of the same gender as the driver.';
    }

    return null;
  }

  Future<void> _loadDriverPhone() async {
    final ride = widget.rideData;

    final String driverId = _safeText(ride[RideService.fieldDriverId], '');

    if (driverId.isEmpty) {
      if (mounted) {
        setState(() {
          _driverPhone = 'No phone';
          _isLoadingDriverPhone = false;
        });
      }
      return;
    }

    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();

      if (mounted && driverDoc.exists && driverDoc.data() != null) {
        final driverData = driverDoc.data()!;
        final String phoneFromUser = _safeText(driverData['phone'], 'No phone');

        setState(() {
          _driverPhone = phoneFromUser;
          _isLoadingDriverPhone = false;
        });
      } else if (mounted) {
        setState(() {
          _driverPhone = 'No phone';
          _isLoadingDriverPhone = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _driverPhone = 'No phone';
          _isLoadingDriverPhone = false;
        });
      }
    }
  }

  Future<void> _loadRiderDefaultLocation() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final String rideNeighborhood = _rideNeighborhoodName(widget.rideData);

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;

        final String userNeighborhood = _safeText(
          userData['defaultNeighborhood'],
          'Other',
        );

        final dynamic homeLocation = userData['homeLocation'];

        _currentUserGender = _safeText(userData['gender'], '');

        if (widget.customPickupLocation != null) {
          _riderSelectedPin = widget.customPickupLocation;
          _riderNeighborhood = widget.customPickupName?.trim().isNotEmpty == true
              ? widget.customPickupName!.trim()
              : rideNeighborhood;
        } else if (rideNeighborhood == userNeighborhood &&
            homeLocation != null &&
            homeLocation is Map &&
            homeLocation['lat'] != null &&
            homeLocation['lng'] != null) {
          _riderSelectedPin = LatLng(
            (homeLocation['lat'] as num).toDouble(),
            (homeLocation['lng'] as num).toDouble(),
          );
          _riderNeighborhood = rideNeighborhood;
        } else {
          _riderSelectedPin =
              AppLocations.neighborhoodCoordinates[rideNeighborhood] ??
                  _driverReferencePin(widget.rideData) ??
                  AppLocations.cairoCenter;
          _riderNeighborhood = rideNeighborhood;
        }
      } else {
        _riderSelectedPin =
            AppLocations.neighborhoodCoordinates[rideNeighborhood] ??
                _driverReferencePin(widget.rideData) ??
                AppLocations.cairoCenter;
        _riderNeighborhood = rideNeighborhood;
      }
    } catch (_) {
      _riderSelectedPin =
          _driverReferencePin(widget.rideData) ?? AppLocations.cairoCenter;
      _riderNeighborhood = _rideNeighborhoodName(widget.rideData);
    } finally {
      if (mounted) {
        setState(() => _isLoadingRiderData = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _searchLocations(String query) async {
    final String? context = AppLocations.osmSearchContext[_riderNeighborhood];
    return LocationService.getSuggestions(query, searchContext: context);
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return 'Not set';

    if (value is Timestamp) {
      final dateTime = value.toDate();

      final String day = dateTime.day.toString().padLeft(2, '0');
      final String month = dateTime.month.toString().padLeft(2, '0');

      final int hour = dateTime.hour;
      final String minute = dateTime.minute.toString().padLeft(2, '0');
      final String period = hour >= 12 ? 'PM' : 'AM';
      final int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '$day/$month • $displayHour:$minute $period';
    }

    return value.toString();
  }

  Future<void> _handleBookRide() async {
    if (_isBooking) return;

    final String? genderBlockReason = _sameGenderBlockReason(widget.rideData);

    if (genderBlockReason != null) {
      _showMessage(message: genderBlockReason, isError: true);
      return;
    }

    if (_riderSelectedPin == null) {
      _showMessage(
        message: 'Please select your meeting location on the map.',
        isError: true,
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      await RideService().bookRide(
        rideId: widget.rideId,
        customPickupLocation: _riderSelectedPin,
        customPickupName: _riderNeighborhood,
      );

      if (!mounted) return;

      _showMessage(
        message: 'Ride booked successfully.',
        isError: false,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmationScreen(
            rideId: widget.rideId,
            rideData: widget.rideData,
            pickupName: _riderNeighborhood,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        message: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  Widget _buildSameGenderBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.navy.withValues(alpha: 0.18),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 14,
            color: AppColors.navy,
          ),
          SizedBox(width: 5),
          Text(
            'Same Gender Only',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.rideData;

    final String driverName = _safeText(
      ride[RideService.fieldDriverName],
      'Driver',
    );

    final String driverImageUrl = _safeText(
      ride[RideService.fieldDriverImageUrl],
      '',
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
    ).split('•').last.trim();

    final String price = _safeText(
      ride[RideService.fieldPrice],
      '0',
    );

    final Map<String, dynamic> carInfo = ride[RideService.fieldCarInfo] is Map
        ? Map<String, dynamic>.from(ride[RideService.fieldCarInfo])
        : <String, dynamic>{};

    final String carMake = _safeText(carInfo['make'], 'Car');
    final String carModel = _safeText(carInfo['model'], '');
    final String carColor = _safeText(carInfo['color'], 'Color not set');
    final String carPlate = _safeText(carInfo['plate'], 'Plate not set');

    final String fullCarTitle = '$carColor $carMake $carModel'.trim();

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

    final bool sameGenderOnly = _isSameGenderOnly(ride);
    final String? genderBlockReason = _sameGenderBlockReason(ride);

    final LatLng? driverPin = _driverReferencePin(ride);

    final bool cannotBookBecauseFull = availableSeats <= 0;
    final bool cannotBookBecauseGender = genderBlockReason != null;

    String buttonText = 'Confirm & Book Ride';

    if (cannotBookBecauseFull) {
      buttonText = 'Ride Full';
    } else if (cannotBookBecauseGender) {
      buttonText = 'Same Gender Only';
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.navy,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.white,
                size: 20,
              ),
              onPressed: _isBooking ? null : () => Navigator.maybePop(context),
            ),
          ),
        ),
        title: const Text(
          'Ride Details',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoadingRiderData || _isLoadingDriverPhone
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.navy),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: AppColors.bgLight,
                      shape: BoxShape.circle,
                    ),
                    child: driverImageUrl.isNotEmpty
                        ? Image.network(
                      driverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          size: 60,
                          color: AppColors.greyText,
                        );
                      },
                    )
                        : const Icon(
                      Icons.person,
                      size: 60,
                      color: AppColors.greyText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    driverName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    _driverPhone,
                    style: const TextStyle(
                      color: AppColors.greyText,
                      fontSize: 14,
                    ),
                  ),
                  if (sameGenderOnly) ...[
                    const SizedBox(height: 12),
                    _buildSameGenderBadge(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildRow(
              'Route:',
              '$originName → $destinationName',
              isValueBold: true,
            ),
            const SizedBox(height: 12),
            _buildRow(
              'Departure Time:',
              '$earliestDeparture - $latestDeparture',
            ),
            const SizedBox(height: 12),
            _buildRow(
              'Price:',
              '$price EGP',
              isValueBold: true,
            ),
            const SizedBox(height: 12),
            _buildRow(
              'Seats Left:',
              '$availableSeats / $totalSeats',
              isValueBold: true,
            ),
            if (genderBlockReason != null) ...[
              const SizedBox(height: 16),
              _buildWarningBox(genderBlockReason),
            ],
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.gold,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullCarTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'License Plate',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            carPlate,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Set Your Meeting Point',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'The red area represents the driver\'s exact destination/pickup. Drag the blue pin or search to where you want to meet them.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.greyText,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_riderSelectedPin != null)
              Container(
                height: 350,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _riderSelectedPin!,
                        initialZoom: 15.0,
                        onTap: (tapPosition, point) {
                          setState(() => _riderSelectedPin = point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.aastmt.campuspool',
                        ),
                        if (driverPin != null)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: driverPin,
                                color: Colors.redAccent.withValues(
                                  alpha: 0.2,
                                ),
                                borderStrokeWidth: 2,
                                borderColor: Colors.redAccent,
                                radius: 80,
                                useRadiusInMeter: true,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (driverPin != null)
                              Marker(
                                point: driverPin,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.directions_car,
                                  color: Colors.redAccent,
                                  size: 30,
                                ),
                              ),
                            Marker(
                              point: _riderSelectedPin!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.navy,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Autocomplete<Map<String, dynamic>>(
                        optionsBuilder:
                            (TextEditingValue textEditingValue) async {
                          final query = textEditingValue.text.trim();

                          if (query.length < 3) {
                            return const Iterable<
                                Map<String, dynamic>>.empty();
                          }

                          if (_debounceTimer?.isActive ?? false) {
                            _debounceTimer!.cancel();
                          }

                          final Completer<
                              Iterable<Map<String, dynamic>>>
                          completer = Completer();

                          _debounceTimer = Timer(
                            const Duration(milliseconds: 500),
                                () async {
                              try {
                                final results =
                                await _searchLocations(query);
                                completer.complete(results);
                              } catch (_) {
                                completer.complete(
                                  const Iterable<
                                      Map<String, dynamic>>.empty(),
                                );
                              }
                            },
                          );

                          return completer.future;
                        },
                        displayStringForOption: (option) {
                          return option['name'];
                        },
                        onSelected: (Map<String, dynamic> selection) {
                          final LatLng newPin = LatLng(
                            selection['lat'],
                            selection['lon'],
                          );

                          setState(() => _riderSelectedPin = newPin);
                          _mapController.move(newPin, 15.0);
                          FocusScope.of(context).unfocus();
                        },
                        fieldViewBuilder: (
                            context,
                            controller,
                            focusNode,
                            onFieldSubmitted,
                            ) {
                          return Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Search meeting point...',
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.navy,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 48),
            _isBooking
                ? const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: AppColors.navy,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Booking your ride...',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
                : CustomNavyButton(
              text: buttonText,
              onPressed: () {
                if (cannotBookBecauseFull) {
                  _showMessage(
                    message: 'This ride is already full.',
                    isError: true,
                  );
                  return;
                }

                if (cannotBookBecauseGender) {
                  _showMessage(
                    message: genderBlockReason,
                    isError: true,
                  );
                  return;
                }

                _handleBookRide();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
      String label,
      String value, {
        bool isValueBold = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.greyText,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isValueBold ? AppColors.navy : AppColors.black,
              fontWeight: isValueBold ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}