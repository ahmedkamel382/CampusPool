import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

import '../constants/app_locations.dart';
import '../theme/app_colors.dart';
import '../services/ride_service.dart';

import 'offer_ride_screen.dart';
import 'find_ride_screen.dart';
import 'ride_details_screen.dart';

enum RideDirectionFilter {
  toCollege,
  toHome,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _activeFilters;
  LatLng? _customPickupLocation;
  String? _customPickupName;

  LatLng? _currentUserHomeLocation;
  String? _currentUserDefaultNeighborhood;
  // ignore: unused_field
  bool _hasCar = false;

  RideDirectionFilter _selectedDirection = RideDirectionFilter.toCollege;

  // --- APP UPDATE: Pagination Memory ---
  final ScrollController _scrollController = ScrollController();
  int _currentLimit = 10;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserLocation();
    _scrollController.addListener(_onScroll); // Listen to bottom hits
  }

  @override
  void dispose() {
    _scrollController.dispose(); // <-- STRICT GARBAGE COLLECTION
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // User is nearing the bottom. Increase limit to fetch next batch.
      setState(() {
        _currentLimit += 10;
      });
    }
  }

  Future<void> _fetchCurrentUserLocation() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) return;

      final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;

      final LatLng? savedHomeLocation =
      RideService().mapToLatLng(data['homeLocation']);

      final String? defaultNeighborhood =
      data['defaultNeighborhood']?.toString().trim();

      final LatLng? fallbackNeighborhoodLocation =
      defaultNeighborhood != null && defaultNeighborhood.isNotEmpty
          ? AppLocations.neighborhoodCoordinates[defaultNeighborhood]
          : null;

      final bool userHasCar = data['hasCar'] ?? false;

      if (!mounted) return;

      setState(() {
        _currentUserHomeLocation =
            savedHomeLocation ?? fallbackNeighborhoodLocation;
        _currentUserDefaultNeighborhood = defaultNeighborhood;
        _hasCar = userHasCar;
      });
    } catch (_) {
      // Sorting can still work by time if user location cannot be loaded.
    }
  }

  // --- NEW: Optimized Server-Side Stream ---
  Stream<QuerySnapshot<Map<String, dynamic>>> _getOptimizedRideStream() {
    if (_activeFilters == null) {
      return RideService().streamActiveRides(limit: _currentLimit); // Passes limit to service
    }

    final String searchedCampus = _activeFilters!['selectedCampus']?.toString() ?? '';
    final String searchedNeighborhood = _activeFilters!['selectedNeighborhood']?.toString() ?? '';

    if (_selectedDirection == RideDirectionFilter.toHome) {
      return RideService().streamActiveRides(
        originFilter: searchedCampus,
        destinationFilter: searchedNeighborhood,
        limit: _currentLimit,
      );
    } else {
      return RideService().streamActiveRides(
        originFilter: searchedNeighborhood,
        destinationFilter: searchedCampus,
        limit: _currentLimit,
      );
    }
  }

  Future<void> _openFindRide() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const FindRideScreen(),
      ),
    );

    if (result == null) return;

    final bool isLeavingCampus = result['isLeavingCampus'] == true;

    setState(() {
      _activeFilters = result;
      _currentLimit = 10; // Reset limit on new search

      _selectedDirection = isLeavingCampus
          ? RideDirectionFilter.toHome
          : RideDirectionFilter.toCollege;

      if (result['customPickupLocation'] is LatLng) {
        _customPickupLocation = result['customPickupLocation'];
      } else {
        _customPickupLocation = null;
      }

      if (result['customPickupName'] != null) {
        _customPickupName = result['customPickupName'].toString().trim();
      } else {
        _customPickupName = null;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search applied: ${_searchBoxText()}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _openOfferRide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OfferRideScreen(),
      ),
    );
  }

  void _openRideDetails({
    required String rideId,
    required Map<String, dynamic> rideData,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideDetailsScreen(
          rideId: rideId,
          rideData: rideData,
          customPickupLocation: _customPickupLocation,
          customPickupName: _customPickupName,
        ),
      ),
    );
  }

  void _clearSearchFilters() {
    setState(() {
      _activeFilters = null;
      _customPickupLocation = null;
      _customPickupName = null;
      _currentLimit = 10;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search filters cleared.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _changeDirection(RideDirectionFilter direction) {
    if (_selectedDirection == direction) return;

    setState(() {
      _selectedDirection = direction;
      _activeFilters = null;
      _customPickupLocation = null;
      _customPickupName = null;
      _currentLimit = 10;
    });
  }

  String _directionLabel() {
    return _selectedDirection == RideDirectionFilter.toCollege
        ? 'To Campus'
        : 'Leaving Campus';
  }

  bool _isCampusName(String name) {
    return AppLocations.campusCoordinates.containsKey(name);
  }

  String _searchBoxText() {
    if (_activeFilters != null) {
      final bool isLeaving = _activeFilters!['isLeavingCampus'] == true;

      return isLeaving
          ? '${_activeFilters!['selectedCampus']} to ${_activeFilters!['selectedNeighborhood']}'
          : '${_activeFilters!['selectedNeighborhood']} to ${_activeFilters!['selectedCampus']}';
    }

    if (_customPickupName != null && _customPickupName!.trim().isNotEmpty) {
      return 'Pickup from $_customPickupName';
    }

    if (_currentUserDefaultNeighborhood != null &&
        _currentUserDefaultNeighborhood!.trim().isNotEmpty) {
      return '${_directionLabel()} • near $_currentUserDefaultNeighborhood';
    }

    return '${_directionLabel()} rides';
  }

  DateTime? _dateTimeFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _parseTimeString(DateTime date, String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');

      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final String period = parts[1];

      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  DateTime? _targetDateTimeFromFilters() {
    if (_activeFilters == null) return null;

    final DateTime? searchedDate =
    _dateTimeFromDynamic(_activeFilters!['selectedDate']);

    final String? searchedTimeStr =
    _activeFilters!['selectedTimeStr']?.toString().trim();

    if (searchedDate == null ||
        searchedTimeStr == null ||
        searchedTimeStr.isEmpty) {
      return null;
    }

    return _parseTimeString(searchedDate, searchedTimeStr);
  }

  LatLng? _locationFromName(String? name) {
    if (name == null || name.trim().isEmpty) return null;

    return AppLocations.neighborhoodCoordinates[name] ??
        AppLocations.campusCoordinates[name];
  }

  bool _matchesSelectedDirection(Map<String, dynamic> ride) {
    final String originName =
        ride[RideService.fieldOriginName]?.toString() ?? '';

    final String destinationName =
        ride[RideService.fieldDestinationName]?.toString() ?? '';

    final bool originIsCampus = _isCampusName(originName);
    final bool destinationIsCampus = _isCampusName(destinationName);

    if (_selectedDirection == RideDirectionFilter.toHome) {
      return originIsCampus && !destinationIsCampus;
    }

    return !originIsCampus && destinationIsCampus;
  }

  LatLng? _rideComparableLocation(Map<String, dynamic> ride) {
    dynamic locationValue;
    String? locationName;

    if (_selectedDirection == RideDirectionFilter.toHome) {
      locationValue = ride[RideService.fieldDestinationLocation];
      locationName = ride[RideService.fieldDestinationName]?.toString();
    } else {
      locationValue = ride[RideService.fieldOriginLocation];
      locationName = ride[RideService.fieldOriginName]?.toString();
    }

    final LatLng? locationFromMap = RideService().mapToLatLng(locationValue);

    return locationFromMap ?? _locationFromName(locationName);
  }

  double _distanceToTargetKm({
    required Map<String, dynamic> ride,
    required LatLng? targetLocation,
    required Distance distanceCalculator,
  }) {
    if (targetLocation == null) return double.infinity;

    final LatLng? rideLocation = _rideComparableLocation(ride);

    if (rideLocation == null) return double.infinity;

    return distanceCalculator.as(
      LengthUnit.Kilometer,
      targetLocation,
      rideLocation,
    );
  }

  int _timeScoreMinutes({
    required Map<String, dynamic> ride,
    required DateTime targetDateTime,
    required bool hasSearchTargetTime,
  }) {
    final DateTime? rideEarliest =
    RideService().getEarliestDepartureDateTime(ride);

    if (rideEarliest == null) return 999999;

    if (hasSearchTargetTime) {
      return rideEarliest.difference(targetDateTime).inMinutes.abs();
    }

    final DateTime now = DateTime.now();

    if (rideEarliest.isBefore(now)) return 0;

    return rideEarliest.difference(now).inMinutes;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _smartFilterAndSort(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    var activeRides = docs.where((doc) {
      final ride = doc.data();

      final int availableSeats = _safeInt(
        ride[RideService.fieldAvailableSeats],
        0,
      );

      final String status = _safeText(
        ride[RideService.fieldStatus],
        RideService.statusActive,
      );

      if (RideService().isRideExpired(ride)) return false;
      if (status != RideService.statusActive) return false;
      if (availableSeats <= 0) return false;
      if (!_matchesSelectedDirection(ride)) return false;

      return true;
    }).toList();

    LatLng? targetLocation;
    DateTime? targetDateTime;

    final bool hasSearch = _activeFilters != null;

    if (hasSearch) {
      final String searchedCampus =
          _activeFilters!['selectedCampus']?.toString() ?? '';

      final String searchedNeighborhood =
          _activeFilters!['selectedNeighborhood']?.toString() ?? '';

      targetLocation = _customPickupLocation ??
          _locationFromName(searchedNeighborhood) ??
          _currentUserHomeLocation;

      targetDateTime = _targetDateTimeFromFilters();

      activeRides = activeRides.where((doc) {
        final ride = doc.data();

        final String originName =
            ride[RideService.fieldOriginName]?.toString() ?? '';

        final String destinationName =
            ride[RideService.fieldDestinationName]?.toString() ?? '';

        if (_selectedDirection == RideDirectionFilter.toHome) {
          return originName == searchedCampus;
        }

        return destinationName == searchedCampus;
      }).toList();
    } else {
      targetLocation = _currentUserHomeLocation;
      targetDateTime = DateTime.now();
    }

    final bool hasSearchTargetTime = _targetDateTimeFromFilters() != null;
    final DateTime effectiveTargetDateTime = targetDateTime ?? DateTime.now();
    const Distance distanceCalculator = Distance();

    activeRides.sort((a, b) {
      final rideA = a.data();
      final rideB = b.data();

      final double distanceA = _distanceToTargetKm(
        ride: rideA,
        targetLocation: targetLocation,
        distanceCalculator: distanceCalculator,
      );

      final double distanceB = _distanceToTargetKm(
        ride: rideB,
        targetLocation: targetLocation,
        distanceCalculator: distanceCalculator,
      );

      if (targetLocation != null) {
        final bool distanceAIsValid = distanceA.isFinite;
        final bool distanceBIsValid = distanceB.isFinite;

        if (distanceAIsValid && !distanceBIsValid) return -1;
        if (!distanceAIsValid && distanceBIsValid) return 1;

        if (distanceAIsValid && distanceBIsValid) {
          final double distanceDifference = (distanceA - distanceB).abs();

          if (distanceDifference > 0.05) {
            return distanceA.compareTo(distanceB);
          }
        }
      }

      final int timeScoreA = _timeScoreMinutes(
        ride: rideA,
        targetDateTime: effectiveTargetDateTime,
        hasSearchTargetTime: hasSearchTargetTime,
      );

      final int timeScoreB = _timeScoreMinutes(
        ride: rideB,
        targetDateTime: effectiveTargetDateTime,
        hasSearchTargetTime: hasSearchTargetTime,
      );

      if (timeScoreA != timeScoreB) {
        return timeScoreA.compareTo(timeScoreB);
      }

      final DateTime? rideATime =
      RideService().getEarliestDepartureDateTime(rideA);

      final DateTime? rideBTime =
      RideService().getEarliestDepartureDateTime(rideB);

      if (rideATime == null && rideBTime == null) return 0;
      if (rideATime == null) return 1;
      if (rideBTime == null) return -1;

      return rideATime.compareTo(rideBTime);
    });

    return activeRides;
  }

  String _safeText(dynamic value, String fallback) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) return fallback;

    return text;
  }

  int _safeInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return fallback;
  }

  Widget _buildDirectionTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DirectionTabButton(
            text: 'To Campus',
            isSelected: _selectedDirection == RideDirectionFilter.toCollege,
            onTap: () => _changeDirection(RideDirectionFilter.toCollege),
          ),
          _DirectionTabButton(
            text: 'Leaving Campus',
            isSelected: _selectedDirection == RideDirectionFilter.toHome,
            onTap: () => _changeDirection(RideDirectionFilter.toHome),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSearch = _activeFilters != null;

    final userData = context.watch<UserProvider>().userData ?? {};

    final String fullName = userData['fullName']?.toString() ?? 'Student';
    final String firstName = fullName.split(' ').first;

    final bool realTimeHasCar = userData['hasCar'] ?? false;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Welcome, $firstName',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(7.0),
                    child: Image.asset(
                      'assets/aastmt_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openFindRide,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: AppColors.greyText,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _searchBoxText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.greyText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (hasSearch)
                            GestureDetector(
                              onTap: _clearSearchFilters,
                              child: const Icon(
                                Icons.close,
                                color: AppColors.greyText,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- THE FIX: Only render the button and spacing if they have a car ---
                if (realTimeHasCar) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _openOfferRide,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.black,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasSearch ? 'Search Results' : 'Upcoming Rides',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                ),
                _buildDirectionTabs(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // --- APP UPDATE: Utilizing optimized server-side stream here ---
              stream: _getOptimizedRideStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.navy),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Could not load rides.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final rides = _smartFilterAndSort(docs);

                if (rides.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        hasSearch
                            ? 'No rides match your search criteria.'
                            : _selectedDirection ==
                            RideDirectionFilter.toCollege
                            ? 'No rides going to college right now.'
                            : 'No rides going home right now.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.greyText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  controller: _scrollController, // <-- Assign controller here for pagination detection
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: rides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final doc = rides[index];
                    final ride = doc.data();

                    return _RideFeedCard(
                      rideId: doc.id,
                      rideData: ride,
                      onTap: () => _openRideDetails(
                        rideId: doc.id,
                        rideData: ride,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionTabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _DirectionTabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.greyText,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _RideFeedCard extends StatelessWidget {
  final String rideId;
  final Map<String, dynamic> rideData;
  final VoidCallback onTap;

  const _RideFeedCard({
    required this.rideId,
    required this.rideData,
    required this.onTap,
  });

  String _safeText(dynamic value, String fallback) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) return fallback;

    return text;
  }

  int _safeInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return fallback;
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return 'Not set';

    if (value is Timestamp) {
      final dateTime = value.toDate();
      final month = dateTime.month;
      final day = dateTime.day;
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '$month/$day • $displayHour:$minute $period';
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    final List<String> passengerIds = (rideData[RideService.fieldPassengerIds] as List<dynamic>?)
        ?.map((e) => e.toString()).toList() ?? []; // .toList() added for safety
    final bool isAlreadyBooked = currentUid != null && passengerIds.contains(currentUid);
    final String driverId = _safeText(rideData[RideService.fieldDriverId], '');
    final bool isMyRide = currentUid != null && driverId == currentUid;
    final String driverName = _safeText(
      rideData[RideService.fieldDriverName],
      'Driver',
    );

    final String driverImageUrl = _safeText(
      rideData[RideService.fieldDriverImageUrl],
      '',
    );

    final String originName = _safeText(
      rideData[RideService.fieldOriginName],
      'Origin',
    );

    final String destinationName = _safeText(
      rideData[RideService.fieldDestinationName],
      'Destination',
    );

    final String earliestDeparture = _formatTimestamp(
      rideData[RideService.fieldEarliestDeparture],
    );

    final String latestDeparture = _formatTimestamp(
      rideData[RideService.fieldLatestDeparture],
    ).split('•').last.trim();

    final String price = _safeText(
      rideData[RideService.fieldPrice],
      '0',
    );

    final int availableSeats = _safeInt(
      rideData[RideService.fieldAvailableSeats],
      0,
    );

    final int totalSeats = _safeInt(
      rideData[RideService.fieldTotalSeats],
      0,
    );

    final bool sameGenderOnly =
        rideData[RideService.fieldSameGenderOnly] == true;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F2F5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: AppColors.bgLight,
                shape: BoxShape.circle,
              ),
              // --- APP UPDATE: CachedNetworkImage eliminates list stuttering ---
              child: driverImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: driverImageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.person,
                  color: AppColors.greyText,
                  size: 34,
                ),
              )
                  : const Icon(
                Icons.person,
                color: AppColors.greyText,
                size: 34,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$originName → $destinationName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Driver: $driverName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.greyText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$earliestDeparture - $latestDeparture',
                    style: const TextStyle(
                      color: AppColors.greyText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$availableSeats/$totalSeats seats available',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),

                  if (isAlreadyBooked)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha:0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Colors.green),
                          SizedBox(width: 4),
                          Text('Already Booked', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  if (isMyRide)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha:0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_car, size: 12, color: AppColors.navy),
                          SizedBox(width: 4),
                          Text('My Ride', style: TextStyle(color: AppColors.navy, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  if (sameGenderOnly) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.navy.withValues(alpha:0.18),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 13,
                            color: AppColors.navy,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Same Gender Only',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$price EGP',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.greyText,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}