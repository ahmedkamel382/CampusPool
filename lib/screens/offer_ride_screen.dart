import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

import '../constants/app_locations.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_buttons.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/location_picker_map.dart';
import '../services/ride_service.dart';

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  bool isLeavingCampus = true;
  String selectedCampus = 'Engineering/CS';
  String? selectedNeighborhood;
  LatLng? exactLocation;
  // ignore: unused_field
  LatLng? _userPinnedLocation;

  final List<String> campuses = AppLocations.campusCoordinates.keys.toList();

  int seats = 2;

  DateTime? selectedDate = DateTime.now();
  String? earliestDepartureStr;
  String? latestDepartureStr;

  bool sameGenderOnly = false;
  bool _isPublishing = false;

  final TextEditingController _priceController = TextEditingController();

  final List<String> timeOptions = [
    '7:00 AM',
    '7:30 AM',
    '8:00 AM',
    '8:30 AM',
    '9:00 AM',
    '9:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '1:00 PM',
    '1:30 PM',
    '2:00 PM',
    '2:30 PM',
    '3:00 PM',
    '3:30 PM',
    '4:00 PM',
    '4:30 PM',
    '5:00 PM',
    '5:30 PM',
    '6:00 PM',
    '6:30 PM',
    '7:00 PM',
    '7:30 PM',
    '8:00 PM',
    '8:30 PM',
    '9:00 PM',
  ];

  @override
  void dispose() {
    // --- APP UPDATE: Strict Garbage Collection ---
    _priceController.dispose();
    super.dispose();
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required IconData icon,
    required String label,
    required Function(String?) onChanged,
  }) {
    final String? safeValue = items.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: safeValue,
      icon: const Icon(Icons.expand_more, color: AppColors.greyText, size: 28),
      style: const TextStyle(
        color: AppColors.black,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.greyText, fontSize: 16),
        floatingLabelStyle: const TextStyle(
          color: AppColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: Icon(icon, color: AppColors.greyText, size: 24),
        filled: true,
        fillColor: AppColors.bgLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 18,
        ),
      ),
      items: items.map((String item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        );
      }).toList(),
      onChanged: items.isEmpty ? null : onChanged,
    );
  }

  DateTime _parseTimeString(DateTime date, String timeStr) {
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

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<String> _futureTimeOptionsForSelectedDate() {
    if (selectedDate == null) return timeOptions;

    final DateTime now = DateTime.now();

    if (!_isSameDate(selectedDate!, now)) {
      return timeOptions;
    }

    return timeOptions.where((time) {
      final DateTime optionDateTime = _parseTimeString(selectedDate!, time);
      return optionDateTime.isAfter(now);
    }).toList();
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

  Future<void> _publishRide() async {
    if (_isPublishing) return;

    if (selectedNeighborhood == null || exactLocation == null) {
      _showMessage(
        message: 'Please select a drop-off / pickup neighborhood.',
        isError: true,
      );
      return;
    }

    if (selectedDate == null ||
        earliestDepartureStr == null ||
        latestDepartureStr == null) {
      _showMessage(
        message: 'Please select a date and departure times.',
        isError: true,
      );
      return;
    }

    final int? price = int.tryParse(_priceController.text.trim());

    if (price == null || price <= 0) {
      _showMessage(
        message: 'Please enter a valid price.',
        isError: true,
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final DateTime earliestDateTime =
      _parseTimeString(selectedDate!, earliestDepartureStr!);

      final DateTime latestDateTime =
      _parseTimeString(selectedDate!, latestDepartureStr!);

      final DateTime now = DateTime.now();

      if (!latestDateTime.isAfter(earliestDateTime)) {
        throw Exception('Latest departure must be after earliest departure.');
      }

      if (!earliestDateTime.isAfter(now)) {
        throw Exception(
          'Earliest departure time has already passed. Please choose a future time.',
        );
      }

      if (!latestDateTime.isAfter(now)) {
        throw Exception(
          'Latest departure time has already passed. Please choose a future time.',
        );
      }

      final LatLng? campusLocation =
      AppLocations.campusCoordinates[selectedCampus];

      if (campusLocation == null) {
        throw Exception('Selected campus location was not found.');
      }

      final String originName =
      isLeavingCampus ? selectedCampus : selectedNeighborhood!;

      final LatLng originLocation =
      isLeavingCampus ? campusLocation : exactLocation!;

      final String destinationName =
      isLeavingCampus ? selectedNeighborhood! : selectedCampus;

      final LatLng destinationLocation =
      isLeavingCampus ? exactLocation! : campusLocation;

      await RideService().publishRide(
        originName: originName,
        originLocation: originLocation,
        destinationName: destinationName,
        destinationLocation: destinationLocation,
        earliestDeparture: earliestDateTime,
        latestDeparture: latestDateTime,
        price: price,
        totalSeats: seats,
        sameGenderOnly: sameGenderOnly,
      );

      if (!mounted) return;

      _showMessage(
        message: 'Ride published successfully.',
        isError: false,
      );

      Navigator.maybePop(context);
    } catch (e) {
      _showMessage(
        message: e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> availableTimeOptions = _futureTimeOptionsForSelectedDate();

    // Dynamically filter the "Latest" options based on what is selected in "Earliest"
    List<String> latestTimeOptions = availableTimeOptions;
    if (earliestDepartureStr != null && selectedDate != null) {
      final DateTime earliestDateTime = _parseTimeString(selectedDate!, earliestDepartureStr!);
      latestTimeOptions = availableTimeOptions.where((time) {
        final DateTime optionDateTime = _parseTimeString(selectedDate!, time);
        return optionDateTime.isAfter(earliestDateTime);
      }).toList();
    }

    final userData = context.watch<UserProvider>().userData ?? {};
    final String? userDefaultNeighborhood = userData['defaultNeighborhood']?.toString();
    LatLng? userHomeLocation;

    if (userData['homeLocation'] != null) {
      userHomeLocation = LatLng(
        (userData['homeLocation']['lat'] as num).toDouble(),
        (userData['homeLocation']['lng'] as num).toDouble(),
      );
    }

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
              onPressed: _isPublishing ? null : () => Navigator.maybePop(context),
            ),
          ),
        ),
        title: const Text(
          'Offer a Ride',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Route',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildDropdown(
                        label: 'Pickup Location',
                        value: isLeavingCampus
                            ? selectedCampus
                            : selectedNeighborhood,
                        items: isLeavingCampus
                            ? campuses
                            : AppLocations.neighborhoodCoordinates.keys.toList(),
                        icon: Icons.my_location,
                        onChanged: (val) {
                          setState(() {
                            if (isLeavingCampus) {
                              selectedCampus = val!;
                            } else {
                              selectedNeighborhood = val;
                              // Smart Pin Logic
                              if (val == userDefaultNeighborhood && userHomeLocation != null) {
                                exactLocation = userHomeLocation;
                              } else {
                                exactLocation = AppLocations.neighborhoodCoordinates[val];
                              }
                              _userPinnedLocation = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        label: 'Drop-off Location',
                        value: isLeavingCampus
                            ? selectedNeighborhood
                            : selectedCampus,
                        items: isLeavingCampus
                            ? AppLocations.neighborhoodCoordinates.keys.toList()
                            : campuses,
                        icon: Icons.location_on,
                        onChanged: (val) {
                          setState(() {
                            if (isLeavingCampus) {
                              selectedNeighborhood = val;
                              // Smart Pin Logic
                              if (val == userDefaultNeighborhood && userHomeLocation != null) {
                                exactLocation = userHomeLocation;
                              } else {
                                exactLocation = AppLocations.neighborhoodCoordinates[val];
                              }
                              _userPinnedLocation = null;
                            } else {
                              selectedCampus = val!;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.swap_vert,
                    size: 36,
                    color: AppColors.navy,
                  ),
                  onPressed: _isPublishing
                      ? null
                      : () {
                    setState(() {
                      isLeavingCampus = !isLeavingCampus;
                    });
                  },
                ),
              ],
            ),

            if (selectedNeighborhood != null && exactLocation != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: LocationPickerMap(
                  key: ValueKey(selectedNeighborhood),
                  darkTheme: false,
                  initialLocation: exactLocation!,
                  currentNeighborhood: selectedNeighborhood!,
                  // Blue pin shows campus (driver start point)
                  driverLocation: AppLocations.campusCoordinates[selectedCampus],
                  showDriverPin: true,
                  onNeighborhoodChanged: (newNeighborhood) {
                    setState(() {
                      selectedNeighborhood = newNeighborhood;
                    });
                  },
                  onLocationSelected: (newCoords) {
                    setState(() {
                      exactLocation = newCoords;
                      _userPinnedLocation = newCoords;
                    });
                  },
                ),
              ),
            ],

            const SizedBox(height: 24),

            const Text(
              'Departure Schedule',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: _isPublishing
                  ? null
                  : () async {
                final DateTime now = DateTime.now();
                final DateTime today = DateTime(
                  now.year,
                  now.month,
                  now.day,
                );

                final DateTime initialDate = selectedDate == null
                    ? today
                    : DateTime(
                  selectedDate!.year,
                  selectedDate!.month,
                  selectedDate!.day,
                );

                final date = await showDatePicker(
                  context: context,
                  initialDate:
                  initialDate.isBefore(today) ? today : initialDate,
                  firstDate: today,
                  lastDate: today.add(const Duration(days: 30)),
                );

                if (date != null) {
                  setState(() {
                    selectedDate = date;
                    earliestDepartureStr = null;
                    latestDepartureStr = null;
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: AppColors.greyText,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      selectedDate == null
                          ? 'Select Date'
                          : '${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}',
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (availableTimeOptions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha:0.3)),
                ),
                child: const Text(
                  'No available departure times left today. Please choose another date.',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      value: earliestDepartureStr,
                      items: availableTimeOptions,
                      icon: Icons.access_time,
                      label: 'Earliest',
                      onChanged: (val) {
                        setState(() {
                          earliestDepartureStr = val;

                          if (latestDepartureStr != null &&
                              val != null &&
                              selectedDate != null) {
                            final earliestDateTime =
                            _parseTimeString(selectedDate!, val);
                            final latestDateTime = _parseTimeString(
                              selectedDate!,
                              latestDepartureStr!,
                            );

                            if (!latestDateTime.isAfter(earliestDateTime)) {
                              latestDepartureStr = null;
                            }
                          }
                        });
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'to',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: _buildDropdown(
                      value: latestDepartureStr,
                      items: latestTimeOptions,
                      icon: Icons.access_time,
                      label: 'Latest',
                      onChanged: (val) {
                        setState(() => latestDepartureStr = val);
                      },
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            color: AppColors.black,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Price (EGP)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _priceController,
                        hintText: 'e.g. 50',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.people,
                            color: AppColors.black,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Seats',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: _isPublishing
                                ? null
                                : () {
                              if (seats > 1) {
                                setState(() => seats--);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: AppColors.greyText,
                                size: 20,
                              ),
                            ),
                          ),
                          Text(
                            '$seats',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          InkWell(
                            onTap: _isPublishing
                                ? null
                                : () {
                              if (seats < 4) {
                                setState(() => seats++);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: AppColors.greyText,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text(
                'Same Gender Only',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              activeThumbColor: AppColors.navy,
              contentPadding: EdgeInsets.zero,
              value: sameGenderOnly,
              onChanged: _isPublishing
                  ? null
                  : (bool value) {
                setState(() => sameGenderOnly = value);
              },
            ),

            const SizedBox(height: 48),

            _isPublishing
                ? const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.navy),
                  SizedBox(height: 12),
                  Text(
                    'Publishing ride...',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
                : CustomNavyButton(
              text: 'Publish Ride',
              onPressed: _publishRide,
            ),
          ],
        ),
      ),
    );
  }
}