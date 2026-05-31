import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

class RideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _ridesCollection {
    return _firestore.collection('rides');
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection('users');
  }

  // ---------------------------------------------------------------------------
  // STANDARD RIDE FIELD NAMES
  // ---------------------------------------------------------------------------

  static const String fieldDriverId = 'driverId';
  static const String fieldDriverName = 'driverName';
  static const String fieldDriverPhone = 'driverPhone';
  static const String fieldDriverGender = 'driverGender';
  static const String fieldDriverImageUrl = 'driverImageUrl';

  static const String fieldCarInfo = 'carInfo';

  static const String fieldOriginName = 'originName';
  static const String fieldOriginLocation = 'originLocation';
  static const String fieldDestinationName = 'destinationName';
  static const String fieldDestinationLocation = 'destinationLocation';

  static const String fieldEarliestDeparture = 'earliestDeparture';
  static const String fieldLatestDeparture = 'latestDeparture';

  static const String fieldPrice = 'price';
  static const String fieldTotalSeats = 'totalSeats';
  static const String fieldAvailableSeats = 'availableSeats';

  static const String fieldSameGenderOnly = 'sameGenderOnly';
  static const String fieldPassengerIds = 'passengerIds';
  static const String fieldPassengerRoster = 'passengerRoster';

  static const String fieldStatus = 'status';
  static const String fieldCreatedAt = 'createdAt';

  static const String fieldHiddenFromHistoryFor = 'hiddenFromHistoryFor';

  // ---------------------------------------------------------------------------
  // STATUS VALUES
  // ---------------------------------------------------------------------------

  static const String statusActive = 'active';
  static const String statusStarted = 'started';
  static const String statusArrivedAtPickup = 'arrived_at_pickup';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  static const String bookingStatusActive = 'active';
  static const String bookingStatusCancelled = 'cancelled';
  static const String bookingStatusRemoved = 'removed';

  // Booking pickup tracking fields
  static const String bookingFieldIsPickedUp = 'isPickedUp';
  static const String bookingFieldPickedUpAt = 'pickedUpAt';
  static const String bookingFieldDriverArrivedAt = 'driverArrivedAt';

  // ---------------------------------------------------------------------------
  // CANCELLATION TIME-LOCK HELPERS
  // ---------------------------------------------------------------------------

  static const int cancellationLockMinutes = 30;

  DateTime? getEarliestDepartureDateTime(Map<String, dynamic> rideData) {
    final value = rideData[fieldEarliestDeparture];

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

  DateTime? getLatestDepartureDateTime(Map<String, dynamic> rideData) {
    final value = rideData[fieldLatestDeparture];

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

  bool canCancelRideFromData(Map<String, dynamic> rideData) {
    final DateTime? earliestDeparture = getEarliestDepartureDateTime(rideData);

    if (earliestDeparture == null) {
      return false;
    }

    final DateTime lockTime = earliestDeparture.subtract(
      const Duration(minutes: cancellationLockMinutes),
    );

    return DateTime.now().isBefore(lockTime);
  }

  void _checkCancellationTimeLock(Map<String, dynamic> rideData) {
    final DateTime? earliestDeparture = getEarliestDepartureDateTime(rideData);

    if (earliestDeparture == null) {
      throw Exception(
        'Cancellation is locked because departure time is missing.',
      );
    }

    final DateTime lockTime = earliestDeparture.subtract(
      const Duration(minutes: cancellationLockMinutes),
    );

    if (!DateTime.now().isBefore(lockTime)) {
      throw Exception('Cancellation is locked 30 minutes before departure.');
    }
  }

  bool isRideExpired(Map<String, dynamic> rideData) {
    final DateTime? latestDeparture = getLatestDepartureDateTime(rideData);

    if (latestDeparture == null) {
      return false;
    }

    return DateTime.now().isAfter(latestDeparture);
  }

  // ---------------------------------------------------------------------------
  // GENDER HELPER
  // ---------------------------------------------------------------------------

  String _normalizeGender(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';

    if (text.startsWith('m')) return 'male';
    if (text.startsWith('f')) return 'female';

    return text;
  }

  // ---------------------------------------------------------------------------
  // LOCATION HELPERS
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? latLngToMap(LatLng? location) {
    if (location == null) return null;

    return {
      'lat': location.latitude,
      'lng': location.longitude,
    };
  }

  LatLng? mapToLatLng(dynamic locationMap) {
    if (locationMap == null) return null;
    if (locationMap is! Map) return null;

    final lat = locationMap['lat'];
    final lng = locationMap['lng'];

    if (lat == null || lng == null) return null;

    return LatLng(
      (lat as num).toDouble(),
      (lng as num).toDouble(),
    );
  }

  // ---------------------------------------------------------------------------
  // USER PROFILE HELPER
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final userDoc = await _usersCollection.doc(user.uid).get();

    if (!userDoc.exists || userDoc.data() == null) {
      throw Exception('User profile was not found.');
    }

    return userDoc.data()!;
  }

  // ---------------------------------------------------------------------------
  // PASSENGER ROSTER ENTRY BUILDER
  // ---------------------------------------------------------------------------

  Map<String, dynamic> buildPassengerRosterEntry({
    required String riderId,
    required Map<String, dynamic> riderProfile,
    LatLng? customPickupLocation,
    String? customPickupName,
  }) {
    final savedHomeLocation = mapToLatLng(riderProfile['homeLocation']);

    final LatLng? finalPickupLocation =
        customPickupLocation ?? savedHomeLocation;

    final String finalPickupName =
    (customPickupName != null && customPickupName.trim().isNotEmpty)
        ? customPickupName.trim()
        : (riderProfile['defaultNeighborhood'] ?? 'Saved Home Location');

    if (finalPickupLocation == null) {
      throw Exception('No pickup location found for this rider.');
    }

    return {
      'riderId': riderId,
      'riderName': riderProfile['fullName'] ?? '',
      'riderPhone': riderProfile['phone'] ?? '',
      'riderGender': riderProfile['gender'] ?? '',
      'riderImageUrl': riderProfile['profileImageUrl'] ?? '',
      'pickupName': finalPickupName,
      'pickupLocation': latLngToMap(finalPickupLocation),
      'bookingStatus': bookingStatusActive,
      'bookedAt': FieldValue.serverTimestamp(),
      'cancelledAt': null,
      'removedAt': null,
    };
  }

  // ---------------------------------------------------------------------------
  // PREPARE OLD RIDE DOCUMENTS FOR NEW STRUCTURE
  // ---------------------------------------------------------------------------

  Future<void> prepareRideForPhase2(String rideId) async {
    final rideRef = _ridesCollection.doc(rideId);
    final rideDoc = await rideRef.get();

    if (!rideDoc.exists || rideDoc.data() == null) {
      throw Exception('Ride was not found.');
    }

    final data = rideDoc.data()!;
    final Map<String, dynamic> updates = {};

    if (!data.containsKey(fieldPassengerIds)) {
      updates[fieldPassengerIds] = <String>[];
    }

    if (!data.containsKey(fieldPassengerRoster)) {
      updates[fieldPassengerRoster] = <String, dynamic>{};
    }

    if (!data.containsKey(fieldStatus)) {
      updates[fieldStatus] = statusActive;
    }

    if (!data.containsKey(fieldHiddenFromHistoryFor)) {
      updates[fieldHiddenFromHistoryFor] = <String>[];
    }

    if (!data.containsKey(fieldAvailableSeats)) {
      final dynamic totalSeatsValue = data[fieldTotalSeats] ?? data['seats'];

      if (totalSeatsValue is int) {
        updates[fieldAvailableSeats] = totalSeatsValue;
      } else if (totalSeatsValue is num) {
        updates[fieldAvailableSeats] = totalSeatsValue.toInt();
      } else {
        updates[fieldAvailableSeats] = 0;
      }
    }

    if (updates.isNotEmpty) {
      await rideRef.update(updates);
    }
  }

  // ---------------------------------------------------------------------------
  // INSTANT BOOKING TRANSACTION
  // ---------------------------------------------------------------------------

  Future<void> bookRide({
    required String rideId,
    LatLng? customPickupLocation,
    String? customPickupName,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final String riderId = user.uid;

    final riderProfile = await getCurrentUserProfile();

    final passengerEntry = buildPassengerRosterEntry(
      riderId: riderId,
      riderProfile: riderProfile,
      customPickupLocation: customPickupLocation,
      customPickupName: customPickupName,
    );

    final rideRef = _ridesCollection.doc(rideId);

    await _firestore.runTransaction((transaction) async {
      final rideSnapshot = await transaction.get(rideRef);

      if (!rideSnapshot.exists || rideSnapshot.data() == null) {
        throw Exception('Ride was not found.');
      }

      final rideData = rideSnapshot.data()!;

      final String status = rideData[fieldStatus] ?? statusActive;

      if (status != statusActive) {
        throw Exception('This ride is no longer active.');
      }

      if (isRideExpired(rideData)) {
        throw Exception('This ride has already expired.');
      }

      final String driverId = rideData[fieldDriverId] ?? '';

      if (driverId == riderId) {
        throw Exception('You cannot book your own ride.');
      }

      final bool sameGenderOnly = rideData[fieldSameGenderOnly] == true;

      if (sameGenderOnly) {
        final String riderGender = _normalizeGender(riderProfile['gender']);
        final String driverGender = _normalizeGender(
          rideData[fieldDriverGender],
        );

        if (riderGender.isEmpty || driverGender.isEmpty) {
          throw Exception(
            'This ride requires verified gender information.',
          );
        }

        if (riderGender != driverGender) {
          throw Exception(
            'This ride is restricted to riders of the same gender as the driver.',
          );
        }
      }

      final dynamic availableSeatsValue = rideData[fieldAvailableSeats];
      final int availableSeats = availableSeatsValue is int
          ? availableSeatsValue
          : availableSeatsValue is num
          ? availableSeatsValue.toInt()
          : 0;

      if (availableSeats <= 0) {
        throw Exception('This ride is already full.');
      }

      final List<String> passengerIds =
          (rideData[fieldPassengerIds] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
              <String>[];

      if (passengerIds.contains(riderId)) {
        throw Exception('You already booked this ride.');
      }

      final Map<String, dynamic> passengerRoster =
      rideData[fieldPassengerRoster] is Map
          ? Map<String, dynamic>.from(rideData[fieldPassengerRoster])
          : <String, dynamic>{};

      if (passengerRoster.containsKey(riderId)) {
        final existingBooking = passengerRoster[riderId];

        if (existingBooking is Map &&
            existingBooking['bookingStatus'] == bookingStatusActive) {
          throw Exception('You already booked this ride.');
        }
      }

      transaction.update(rideRef, {
        fieldAvailableSeats: availableSeats - 1,
        fieldPassengerIds: FieldValue.arrayUnion([riderId]),
        '$fieldPassengerRoster.$riderId': passengerEntry,
      });
    });
  }

  // ---------------------------------------------------------------------------
  // DRIVER REMOVE PASSENGER BEFORE RIDE STARTS
  // ---------------------------------------------------------------------------

  Future<void> removePassengerFromRide({
    required String rideId,
    required String passengerId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final rideRef = _ridesCollection.doc(rideId);

    await _firestore.runTransaction((transaction) async {
      final rideSnapshot = await transaction.get(rideRef);

      if (!rideSnapshot.exists || rideSnapshot.data() == null) {
        throw Exception('Ride was not found.');
      }

      final rideData = rideSnapshot.data()!;

      final String driverId = rideData[fieldDriverId] ?? '';

      if (driverId != user.uid) {
        throw Exception('Only the driver can remove passengers.');
      }

      final String status = rideData[fieldStatus] ?? statusActive;

      if (status != statusActive) {
        throw Exception(
          'Use Mark No-Show after the ride has started.',
        );
      }

      _checkCancellationTimeLock(rideData);

      final List<String> passengerIds =
          (rideData[fieldPassengerIds] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
              <String>[];

      if (!passengerIds.contains(passengerId)) {
        throw Exception('This rider is not booked on this ride.');
      }

      final dynamic availableSeatsValue = rideData[fieldAvailableSeats];
      final int availableSeats = availableSeatsValue is int
          ? availableSeatsValue
          : availableSeatsValue is num
          ? availableSeatsValue.toInt()
          : 0;

      final dynamic totalSeatsValue = rideData[fieldTotalSeats];
      final int totalSeats = totalSeatsValue is int
          ? totalSeatsValue
          : totalSeatsValue is num
          ? totalSeatsValue.toInt()
          : availableSeats + 1;

      final int newAvailableSeats =
      (availableSeats + 1) > totalSeats ? totalSeats : availableSeats + 1;

      transaction.update(rideRef, {
        fieldAvailableSeats: newAvailableSeats,
        fieldPassengerIds: FieldValue.arrayRemove([passengerId]),
        '$fieldPassengerRoster.$passengerId.bookingStatus':
        bookingStatusRemoved,
        '$fieldPassengerRoster.$passengerId.removedAt':
        FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------------------
  // DRIVER MARK PASSENGER AS NO-SHOW AFTER RIDE STARTS
  // ---------------------------------------------------------------------------

  Future<void> markPassengerNoShow({
    required String rideId,
    required String passengerId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final rideRef = _ridesCollection.doc(rideId);

    await _firestore.runTransaction((transaction) async {
      final rideSnapshot = await transaction.get(rideRef);

      if (!rideSnapshot.exists || rideSnapshot.data() == null) {
        throw Exception('Ride was not found.');
      }

      final rideData = rideSnapshot.data()!;

      final String driverId = rideData[fieldDriverId] ?? '';

      if (driverId != user.uid) {
        throw Exception('Only the driver can mark no-shows.');
      }

      final String status = rideData[fieldStatus] ?? statusActive;

      final bool rideIsInProgress =
          status == statusStarted || status == statusArrivedAtPickup;

      if (!rideIsInProgress) {
        throw Exception('You can only mark no-shows after the ride starts.');
      }

      final dynamic roster = rideData[fieldPassengerRoster];

      if (roster is! Map || !roster.containsKey(passengerId)) {
        throw Exception('This rider is not booked on this ride.');
      }

      final booking = roster[passengerId];

      if (booking is Map) {
        final String bookingStatus =
            booking['bookingStatus']?.toString() ?? bookingStatusActive;

        if (bookingStatus != bookingStatusActive) {
          throw Exception('This rider is already not active on this ride.');
        }

        if (booking[bookingFieldIsPickedUp] == true) {
          throw Exception('This rider has already been scanned.');
        }
      }

      final dynamic availableSeatsValue = rideData[fieldAvailableSeats];
      final int availableSeats = availableSeatsValue is int
          ? availableSeatsValue
          : availableSeatsValue is num
          ? availableSeatsValue.toInt()
          : 0;

      final dynamic totalSeatsValue = rideData[fieldTotalSeats];
      final int totalSeats = totalSeatsValue is int
          ? totalSeatsValue
          : totalSeatsValue is num
          ? totalSeatsValue.toInt()
          : availableSeats + 1;

      final int newAvailableSeats =
      (availableSeats + 1) > totalSeats ? totalSeats : availableSeats + 1;

      transaction.update(rideRef, {
        fieldAvailableSeats: newAvailableSeats,
        fieldPassengerIds: FieldValue.arrayRemove([passengerId]),
        '$fieldPassengerRoster.$passengerId.bookingStatus':
        bookingStatusRemoved,
        '$fieldPassengerRoster.$passengerId.removedAt':
        FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------------------
  // RIDER CANCEL THEIR OWN BOOKING
  // ---------------------------------------------------------------------------

  Future<void> cancelMyBooking({
    required String rideId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final String riderId = user.uid;
    final rideRef = _ridesCollection.doc(rideId);

    await _firestore.runTransaction((transaction) async {
      final rideSnapshot = await transaction.get(rideRef);

      if (!rideSnapshot.exists || rideSnapshot.data() == null) {
        throw Exception('Ride was not found.');
      }

      final rideData = rideSnapshot.data()!;

      final String status = rideData[fieldStatus] ?? statusActive;

      if (status != statusActive) {
        throw Exception('This ride is no longer active.');
      }

      _checkCancellationTimeLock(rideData);

      final List<String> passengerIds =
          (rideData[fieldPassengerIds] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
              <String>[];

      if (!passengerIds.contains(riderId)) {
        throw Exception('You do not have an active booking on this ride.');
      }

      final dynamic availableSeatsValue = rideData[fieldAvailableSeats];
      final int availableSeats = availableSeatsValue is int
          ? availableSeatsValue
          : availableSeatsValue is num
          ? availableSeatsValue.toInt()
          : 0;

      final dynamic totalSeatsValue = rideData[fieldTotalSeats];
      final int totalSeats = totalSeatsValue is int
          ? totalSeatsValue
          : totalSeatsValue is num
          ? totalSeatsValue.toInt()
          : availableSeats + 1;

      final int newAvailableSeats =
      (availableSeats + 1) > totalSeats ? totalSeats : availableSeats + 1;

      transaction.update(rideRef, {
        fieldAvailableSeats: newAvailableSeats,
        fieldPassengerIds: FieldValue.arrayRemove([riderId]),
        '$fieldPassengerRoster.$riderId.bookingStatus': bookingStatusCancelled,
        '$fieldPassengerRoster.$riderId.cancelledAt':
        FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------------------
  // DRIVER CANCEL THEIR OWN RIDE
  // ---------------------------------------------------------------------------

  Future<void> cancelMyRide({
    required String rideId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final rideRef = _ridesCollection.doc(rideId);

    await _firestore.runTransaction((transaction) async {
      final rideSnapshot = await transaction.get(rideRef);

      if (!rideSnapshot.exists || rideSnapshot.data() == null) {
        throw Exception('Ride was not found.');
      }

      final rideData = rideSnapshot.data()!;

      final String driverId = rideData[fieldDriverId] ?? '';

      if (driverId != user.uid) {
        throw Exception('Only the driver can cancel this ride.');
      }

      final String status = rideData[fieldStatus] ?? statusActive;

      if (status != statusActive) {
        throw Exception('This ride is already not active.');
      }

      _checkCancellationTimeLock(rideData);

      final Map<String, dynamic> updates = {
        fieldStatus: statusCancelled,
        fieldAvailableSeats: 0,
        fieldPassengerIds: <String>[],
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': user.uid,
      };

      final dynamic roster = rideData[fieldPassengerRoster];

      if (roster is Map) {
        final Map<String, dynamic> rosterMap = Map<String, dynamic>.from(roster);

        for (final entry in rosterMap.entries) {
          final passengerId = entry.key;
          final passengerData = entry.value;

          if (passengerData is Map) {
            final String bookingStatus =
                passengerData['bookingStatus']?.toString() ??
                    bookingStatusActive;

            if (bookingStatus == bookingStatusActive) {
              updates['$fieldPassengerRoster.$passengerId.bookingStatus'] =
                  bookingStatusCancelled;
              updates['$fieldPassengerRoster.$passengerId.cancelledAt'] =
                  FieldValue.serverTimestamp();
            }
          }
        }
      }

      transaction.update(rideRef, updates);
    });
  }

  // ---------------------------------------------------------------------------
  // DRIVER TRIP STATUS UPDATES
  // ---------------------------------------------------------------------------

  /// Valid transitions:
  /// active → started
  /// started → completed
  /// arrived_at_pickup → completed
  ///
  /// Completing requires all active passengers to have isPickedUp == true.
  /// Passengers marked as removed/no-show are ignored because their
  /// bookingStatus is no longer active.
  Future<void> updateTripStatus({
    required String rideId,
    required String newStatus,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    const List<String> validStatuses = [
      statusStarted,
      statusCompleted,
    ];

    if (!validStatuses.contains(newStatus)) {
      throw Exception('Invalid status: $newStatus');
    }

    final rideRef = _ridesCollection.doc(rideId);

    await _firestore.runTransaction((transaction) async {
      final rideSnapshot = await transaction.get(rideRef);

      if (!rideSnapshot.exists || rideSnapshot.data() == null) {
        throw Exception('Ride was not found.');
      }

      final rideData = rideSnapshot.data()!;
      final String driverId = rideData[fieldDriverId] ?? '';

      if (driverId != user.uid) {
        throw Exception('Only the driver can update the trip status.');
      }

      final String currentStatus = rideData[fieldStatus] ?? statusActive;

      final Map<String, List<String>> allowedTransitions = {
        statusActive: [statusStarted],
        statusStarted: [statusCompleted],
        statusArrivedAtPickup: [statusCompleted],
      };

      final List<String> allowedNextStatuses =
          allowedTransitions[currentStatus] ?? [];

      if (!allowedNextStatuses.contains(newStatus)) {
        throw Exception(
          'Cannot transition from "$currentStatus" to "$newStatus".',
        );
      }

      if (newStatus == statusStarted && isRideExpired(rideData)) {
        throw Exception('This ride has already expired and cannot be started.');
      }

      if (newStatus == statusCompleted) {
        final dynamic roster = rideData[fieldPassengerRoster];

        if (roster is Map) {
          final rosterMap = Map<String, dynamic>.from(roster);

          for (final entry in rosterMap.entries) {
            final booking = entry.value;

            if (booking is! Map) continue;

            final String bookingStatus =
                booking['bookingStatus']?.toString() ?? bookingStatusActive;

            if (bookingStatus != bookingStatusActive) continue;

            final bool isPickedUp = booking[bookingFieldIsPickedUp] == true;

            if (!isPickedUp) {
              throw Exception(
                'All active riders must be scanned or marked no-show before completing the ride.',
              );
            }
          }
        }
      }

      transaction.update(rideRef, {
        fieldStatus: newStatus,
        '${newStatus}At': FieldValue.serverTimestamp(),
      });
    });
  }

  // Backward compatibility:
  // If any old screen still calls deleteMyRide(), it will cancel the ride instead.
  Future<void> deleteMyRide({
    required String rideId,
  }) async {
    await cancelMyRide(rideId: rideId);
  }

  // ---------------------------------------------------------------------------
  // PER-PASSENGER PICKUP TRACKING
  // ---------------------------------------------------------------------------

  /// Driver marks that they have arrived at this passenger's pickup location.
  Future<void> markDriverArrivedAtPassenger({
    required String rideId,
    required String passengerId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final rideRef = _ridesCollection.doc(rideId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(rideRef);

      if (!snap.exists || snap.data() == null) {
        throw Exception('Ride was not found.');
      }

      final data = snap.data()!;

      if ((data[fieldDriverId] ?? '') != user.uid) {
        throw Exception('Only the driver can mark arrivals.');
      }

      final String status = data[fieldStatus] ?? statusActive;

      if (status != statusStarted && status != statusArrivedAtPickup) {
        throw Exception('The ride must be started before marking arrivals.');
      }

      final dynamic roster = data[fieldPassengerRoster];

      if (roster is! Map || !roster.containsKey(passengerId)) {
        throw Exception('This rider is not booked on this ride.');
      }

      final booking = roster[passengerId];

      if (booking is Map) {
        final String bookingStatus =
            booking['bookingStatus']?.toString() ?? bookingStatusActive;

        if (bookingStatus != bookingStatusActive) {
          throw Exception('This rider is no longer active on this ride.');
        }

        if (booking[bookingFieldIsPickedUp] == true) {
          throw Exception('This rider has already been scanned.');
        }
      }

      transaction.update(rideRef, {
        '$fieldPassengerRoster.$passengerId.$bookingFieldDriverArrivedAt':
        FieldValue.serverTimestamp(),
      });
    });
  }

  /// Driver scans the rider's QR code to confirm they are on board.
  /// QR format: campuspool:{rideId}:{passengerId}
  Future<void> scanPassengerQR({
    required String rideId,
    required String passengerId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final rideRef = _ridesCollection.doc(rideId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(rideRef);

      if (!snap.exists || snap.data() == null) {
        throw Exception('Ride was not found.');
      }

      final data = snap.data()!;

      if ((data[fieldDriverId] ?? '') != user.uid) {
        throw Exception('Only the driver can scan QR codes.');
      }

      final String status = data[fieldStatus] ?? statusActive;

      if (status != statusStarted && status != statusArrivedAtPickup) {
        throw Exception('The ride must be started before scanning.');
      }

      final dynamic roster = data[fieldPassengerRoster];

      if (roster is! Map || !roster.containsKey(passengerId)) {
        throw Exception('This rider is not booked on this ride.');
      }

      final booking = roster[passengerId];

      if (booking is Map) {
        final String bookingStatus =
            booking['bookingStatus']?.toString() ?? bookingStatusActive;

        if (bookingStatus != bookingStatusActive) {
          throw Exception('This rider\'s booking is no longer active.');
        }

        if (booking[bookingFieldIsPickedUp] == true) {
          throw Exception('This rider has already been scanned.');
        }
      }

      transaction.update(rideRef, {
        '$fieldPassengerRoster.$passengerId.$bookingFieldIsPickedUp': true,
        '$fieldPassengerRoster.$passengerId.$bookingFieldPickedUpAt':
        FieldValue.serverTimestamp(),
      });
    });
  }

  /// Returns true if all active passengers on the ride have been scanned.
  /// Removed/no-show/cancelled riders are ignored.
  bool allPassengersScanned(Map<String, dynamic> rideData) {
    final dynamic roster = rideData[fieldPassengerRoster];

    if (roster is! Map) {
      return true;
    }

    final rosterMap = Map<String, dynamic>.from(roster);

    final activeBookings = rosterMap.values.where((booking) {
      if (booking is! Map) return false;

      return (booking['bookingStatus']?.toString() ?? bookingStatusActive) ==
          bookingStatusActive;
    });

    if (activeBookings.isEmpty) {
      return true;
    }

    return activeBookings.every(
          (booking) => (booking as Map)[bookingFieldIsPickedUp] == true,
    );
  }

  // ---------------------------------------------------------------------------
  // REMOVE RIDE FROM CURRENT USER HISTORY
  // ---------------------------------------------------------------------------

  Future<void> removeRideFromMyHistory({
    required String rideId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    await _ridesCollection.doc(rideId).update({
      fieldHiddenFromHistoryFor: FieldValue.arrayUnion([user.uid]),
    });
  }

  // ---------------------------------------------------------------------------
  // DRIVER RATING
  // ---------------------------------------------------------------------------

  /// Rider submits a star rating (1–5) for the driver after ride completion.
  /// Uses a transaction to atomically update ratingSum + ratingCount on the
  /// driver's Firestore profile. Marks the booking as rated to prevent re-rating.
  Future<void> submitDriverRating({
    required String rideId,
    required String driverUid,
    required int stars,
  }) async {
    if (stars < 1 || stars > 5) {
      throw Exception('Rating must be between 1 and 5 stars.');
    }

    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final rideRef = _ridesCollection.doc(rideId);
    final driverRef = _usersCollection.doc(driverUid);

    await _firestore.runTransaction((transaction) async {
      final rideSnap = await transaction.get(rideRef);

      if (!rideSnap.exists || rideSnap.data() == null) {
        throw Exception('Ride was not found.');
      }

      final rideData = rideSnap.data()!;

      final String status = rideData[fieldStatus] ?? statusActive;

      if (status != statusCompleted) {
        throw Exception('You can only rate a completed ride.');
      }

      final dynamic roster = rideData[fieldPassengerRoster];

      if (roster is! Map || !roster.containsKey(user.uid)) {
        throw Exception('You were not on this ride.');
      }

      final booking = roster[user.uid];

      if (booking is Map && booking['hasRated'] == true) {
        throw Exception('You have already rated this driver.');
      }

      final driverSnap = await transaction.get(driverRef);
      final driverData = driverSnap.exists ? driverSnap.data() ?? {} : {};

      final int currentSum = (driverData['ratingSum'] ?? 0).toInt();
      final int currentCount = (driverData['ratingCount'] ?? 0).toInt();

      transaction.update(driverRef, {
        'ratingSum': currentSum + stars,
        'ratingCount': currentCount + 1,
      });

      transaction.update(rideRef, {
        '$fieldPassengerRoster.${user.uid}.hasRated': true,
        '$fieldPassengerRoster.${user.uid}.ratedAt':
        FieldValue.serverTimestamp(),
      });
    });
  }

  /// Returns true if the current user has already rated this ride.
  bool hasAlreadyRated(Map<String, dynamic> rideData, String uid) {
    final dynamic roster = rideData[fieldPassengerRoster];

    if (roster is! Map || !roster.containsKey(uid)) {
      return false;
    }

    final booking = roster[uid];

    return booking is Map && booking['hasRated'] == true;
  }

  // ---------------------------------------------------------------------------
  // ACTIVE RIDES STREAM FOR HOME FEED
  // ---------------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> streamActiveRides({
    String? originFilter,
    String? destinationFilter,
    int limit = 10,
  }) {
    Query<Map<String, dynamic>> query = _ridesCollection.where(
      fieldStatus,
      isEqualTo: statusActive,
    );

    if (originFilter != null && originFilter.isNotEmpty) {
      query = query.where(fieldOriginName, isEqualTo: originFilter);
    }

    if (destinationFilter != null && destinationFilter.isNotEmpty) {
      query = query.where(fieldDestinationName, isEqualTo: destinationFilter);
    }

    return query.snapshots();
  }

  // ---------------------------------------------------------------------------
  // CREATE / PUBLISH RIDE
  // ---------------------------------------------------------------------------

  Future<String> publishRide({
    required String originName,
    required LatLng originLocation,
    required String destinationName,
    required LatLng destinationLocation,
    required DateTime earliestDeparture,
    required DateTime latestDeparture,
    required int price,
    required int totalSeats,
    required bool sameGenderOnly,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently logged in.');
    }

    final userDoc = await _usersCollection.doc(user.uid).get();

    if (!userDoc.exists || userDoc.data() == null) {
      throw Exception('User profile was not found.');
    }

    final userData = userDoc.data()!;

    final bool hasCar = userData['hasCar'] ?? false;

    if (!hasCar) {
      throw Exception('You must add car information before offering a ride.');
    }

    final Map<String, dynamic> carInfo = userData['carInfo'] is Map
        ? Map<String, dynamic>.from(userData['carInfo'])
        : <String, dynamic>{};

    if (carInfo.isEmpty) {
      throw Exception('Car information is missing from your profile.');
    }

    final docRef = await _ridesCollection.add({
      fieldDriverId: user.uid,
      fieldDriverName: userData['fullName'] ?? '',
      fieldDriverPhone: userData['phone'] ?? '',
      fieldDriverGender: userData['gender'] ?? '',
      fieldDriverImageUrl: userData['profileImageUrl'] ?? '',
      fieldCarInfo: carInfo,
      fieldOriginName: originName,
      fieldOriginLocation: latLngToMap(originLocation),
      fieldDestinationName: destinationName,
      fieldDestinationLocation: latLngToMap(destinationLocation),
      fieldEarliestDeparture: Timestamp.fromDate(earliestDeparture),
      fieldLatestDeparture: Timestamp.fromDate(latestDeparture),
      fieldPrice: price,
      fieldTotalSeats: totalSeats,
      fieldAvailableSeats: totalSeats,
      fieldSameGenderOnly: sameGenderOnly,
      fieldPassengerIds: <String>[],
      fieldPassengerRoster: <String, dynamic>{},
      fieldHiddenFromHistoryFor: <String>[],
      fieldStatus: statusActive,
      fieldCreatedAt: FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // ---------------------------------------------------------------------------
  // HELPERS FOR TESTING / FUTURE SCREENS
  // ---------------------------------------------------------------------------

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRide(String rideId) {
    return _ridesCollection.doc(rideId).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getRide(String rideId) async {
    return _ridesCollection.doc(rideId).get();
  }
}