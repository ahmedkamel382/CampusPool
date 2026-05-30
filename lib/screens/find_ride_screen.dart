import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../constants/app_locations.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_buttons.dart';
import '../widgets/location_picker_map.dart';

class FindRideScreen extends StatefulWidget {
  const FindRideScreen({super.key});

  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  bool isLeavingCampus = true;
  String selectedCampus = 'Engineering/CS';
  String? selectedNeighborhood;
  LatLng? exactLocation;

  bool sameGenderOnly = false;

  // NEW: Date Picker Logic
  DateTime? selectedDate = DateTime.now();
  String selectedTime = '';

  final List<String> campuses = AppLocations.campusCoordinates.keys.toList();

  final List<String> times = [
    '9:00 AM', '10:00 AM', '11:00 AM', '12:00 PM',
    '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM',
    '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM',
  ];

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required IconData icon,
    required String label,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: const Icon(Icons.expand_more, color: AppColors.greyText, size: 28),
      style: const TextStyle(
        color: AppColors.black,
        fontSize: 16,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      items: items.map((String item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  // FIX: Manual time parsing for blurring passed times correctly
  bool _isTimePassed(String timeStr) {
    if (selectedDate == null) return false;
    final now = DateTime.now();
    if (selectedDate!.year != now.year || selectedDate!.month != now.month || selectedDate!.day != now.day) {
      return false;
    }
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final String period = parts[1];

      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {hour = 0;}

      final slotDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      return slotDateTime.isBefore(now);
    } catch (_) {
      return false;
    }
  }

  void _handleSearchForRides() {
    if (selectedNeighborhood == null || exactLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a neighborhood and pickup pin first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (selectedTime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a preferred time.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'isLeavingCampus': isLeavingCampus,
      'selectedCampus': selectedCampus,
      'selectedNeighborhood': selectedNeighborhood,
      'customPickupLocation': exactLocation,
      'customPickupName': selectedNeighborhood,
      'sameGenderOnly': sameGenderOnly,
      'selectedDate': selectedDate,
      'selectedTimeStr': selectedTime, // Sends time for Smart Sorting
    });
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.navy,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.white,
                size: 20,
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        )
            : null,
        title: const Text(
          'Find a Ride',
          style: TextStyle(
            color: AppColors.black,
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
                      // FIX: Wrapped in addPostFrameCallback to prevent Red Screen Crash!
                      _buildDropdown(
                        label: 'Pickup Location',
                        value: isLeavingCampus ? selectedCampus : selectedNeighborhood,
                        items: isLeavingCampus
                            ? campuses
                            : AppLocations.neighborhoodCoordinates.keys.toList(),
                        icon: Icons.my_location,
                        onChanged: (val) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
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
                                }
                              });
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      _buildDropdown(
                        label: 'Drop-off Location',
                        value: isLeavingCampus ? selectedNeighborhood : selectedCampus,
                        items: isLeavingCampus
                            ? AppLocations.neighborhoodCoordinates.keys.toList()
                            : campuses,
                        icon: Icons.location_on,
                        onChanged: (val) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                if (isLeavingCampus) {
                                  selectedNeighborhood = val;
                                  // Smart Pin Logic
                                  if (val == userDefaultNeighborhood && userHomeLocation != null) {
                                    exactLocation = userHomeLocation;
                                  } else {
                                    exactLocation = AppLocations.neighborhoodCoordinates[val];
                                  }
                                } else {
                                  selectedCampus = val!;
                                }
                              });
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
                  onPressed: () {
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
                    // Blue pin = campus (the other end of the ride)
                    driverLocation: AppLocations.campusCoordinates[selectedCampus],
                    showDriverPin: true,
                    onNeighborhoodChanged: (newNeighborhood) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => selectedNeighborhood = newNeighborhood);
                      });
                    },
                    onLocationSelected: (newCoords) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => exactLocation = newCoords);
                      });
                    },
                  ),
              ),
            ],

            const SizedBox(height: 24),

            SwitchListTile(
              title: const Text(
                'Same Gender Only',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Only show rides from my gender',
                style: TextStyle(fontSize: 12),
              ),
              activeThumbColor: AppColors.navy,
              contentPadding: EdgeInsets.zero,
              value: sameGenderOnly,
              onChanged: (bool value) {
                setState(() => sameGenderOnly = value);
              },
            ),

            const SizedBox(height: 32),

            const Text(
              'Departure Schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),

            const SizedBox(height: 16),

            // DATE PICKER UI
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) {
                  setState(() {
                    selectedDate = date;
                    selectedTime = ''; // reset so they don't submit a passed time
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(color: AppColors.bgLight, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.greyText, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      selectedDate == null ? 'Select Date' : '${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}',
                      style: const TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: times.length,
              itemBuilder: (context, index) {
                final time = times[index];
                final isPassed = _isTimePassed(time);
                final isSelected = selectedTime == time;

                return GestureDetector(
                  onTap: isPassed ? null : () => setState(() => selectedTime = time),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isPassed ? Colors.grey.withValues(alpha:0.1) : (isSelected ? AppColors.navy : AppColors.bgLight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      time,
                      style: TextStyle(
                        color: isPassed ? Colors.grey.withValues(alpha:0.4) : (isSelected ? AppColors.white : AppColors.greyText),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        decoration: isPassed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 48),

            CustomNavyButton(
              text: 'Search for Rides',
              onPressed: _handleSearchForRides,
            ),
          ],
        ),
      ),
    );
  }
}