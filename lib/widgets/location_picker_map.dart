import 'dart:async';
import '../utils/debouncer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_locations.dart';
import '../theme/app_colors.dart';
import '../services/location_service.dart';

class LocationPickerMap extends StatefulWidget {
  final LatLng initialLocation;
  final String currentNeighborhood;
  final bool darkTheme;
  final Function(LatLng) onLocationSelected;
  final Function(String) onNeighborhoodChanged;
  final LatLng? driverLocation;
  final bool showDriverPin;

  const LocationPickerMap({
    super.key,
    required this.initialLocation,
    required this.currentNeighborhood,
    this.darkTheme = true,
    this.driverLocation,
    this.showDriverPin = false,
    required this.onLocationSelected,
    required this.onNeighborhoodChanged,
  });

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  late LatLng _currentPosition;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  late final LatLng _originalSavedLocation;
  late final String _originalNeighborhood;

  bool _isSearching = false;
  bool _isFetchingLocation = false;
  bool _isUpdatingFromGPS = false;
  final Debouncer _debouncer = Debouncer(milliseconds: 500);  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialLocation;

    // Memorize the exact starting point when the map first boots up
    _originalSavedLocation = widget.initialLocation;
    _originalNeighborhood = widget.currentNeighborhood;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose(); // --- APP UPDATE: Strict Garbage Collection added here ---
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the dropdown changed...
    if (widget.currentNeighborhood != oldWidget.currentNeighborhood) {
      if (_isUpdatingFromGPS) {
        _isUpdatingFromGPS = false;
      } else {
        _performReset(widget.currentNeighborhood);
      }
    }
  }

  // --- THE NEW SMART RESET FUNCTION ---
  void _performReset(String targetNeighborhood) {
    setState(() {
      _searchController.clear();
      _suggestions.clear();

      // If we are resetting inside their original neighborhood...
      if (targetNeighborhood == _originalNeighborhood) {
        _currentPosition = _originalSavedLocation; // Go EXACTLY to their saved house!
        _mapController.move(_currentPosition, 15.0); // Zoom in closer
      } else {
        // If they are exploring a different neighborhood, go to the generic center
        _currentPosition = AppLocations.neighborhoodCoordinates[targetNeighborhood] ?? AppLocations.cairoCenter;
        _mapController.move(_currentPosition, 14.0); // Zoom out
      }
    });

    FocusScope.of(context).unfocus();
    widget.onLocationSelected(_currentPosition);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied.');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Permissions are permanently denied.');

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng myLocation = LatLng(position.latitude, position.longitude);
      const Distance distanceCalc = Distance();

      double distToCairoCenter = distanceCalc.as(LengthUnit.Meter, myLocation, AppLocations.cairoCenter).toDouble();
      if (distToCairoCenter > AppLocations.maxCairoRadiusMeters) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Warning: Your location is outside the supported Greater Cairo area.'),
                backgroundColor: Colors.redAccent,
                duration: Duration(seconds: 4),
              )
          );
        }
        return;
      }

      String bestMatch = 'Other';
      double minDistance = double.infinity;

      for (var entry in AppLocations.neighborhoodCoordinates.entries) {
        if (entry.key == 'Other') continue;
        double dist = distanceCalc.as(LengthUnit.Meter, myLocation, entry.value).toDouble();
        if (dist < minDistance) {
          minDistance = dist;
          bestMatch = entry.key;
        }
      }

      if (minDistance > AppLocations.neighborhoodRadiusMeters) {
        bestMatch = 'Other';
      }

      if (bestMatch != widget.currentNeighborhood) {
        _isUpdatingFromGPS = true;
        widget.onNeighborhoodChanged(bestMatch);
      }

      setState(() {
        _currentPosition = myLocation;
        _searchController.text = "My Current Location";
        _suggestions.clear();
        _mapController.move(myLocation, 16.0);
      });

      widget.onLocationSelected(myLocation);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _onSearchChanged(String query) {
    // 1. Clean the query to ignore trailing spaces (The Spacebar Fix!)
    final cleanQuery = query.trim();

    if (cleanQuery.length < 3) {
      setState(() => _suggestions = []);
      return;
    }

    // 2. Use Debouncer class
    _debouncer.run(() async {
      setState(() => _isSearching = true);

      String contextData = AppLocations.osmSearchContext[widget.currentNeighborhood] ?? '';
      final results = await LocationService.getSuggestions(cleanQuery, searchContext: contextData);

      // Only update the UI if the user hasn't left the screen while it was loading
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectSuggestion(Map<String, dynamic> place) {
    LatLng newLocation = LatLng(place['lat'], place['lon']);
    setState(() {
      _currentPosition = newLocation;
      _searchController.text = place['name'].toString().split(',').first;
      _suggestions = [];
      _mapController.move(newLocation, 16.0);
    });
    FocusScope.of(context).unfocus();
    widget.onLocationSelected(newLocation);
  }

  @override
  Widget build(BuildContext context) {
    // --- THEME COLOR LOGIC ---
    final Color textColor = widget.darkTheme ? AppColors.white : AppColors.black;
    final Color hintColor = widget.darkTheme ? Colors.white54 : AppColors.greyText;
    final Color fillColor = widget.darkTheme ? Colors.white10 : AppColors.bgLight;
    final Color iconColor = widget.darkTheme ? AppColors.white : AppColors.navy;
    final Color dropdownBg = widget.darkTheme ? AppColors.navy : AppColors.white;
    final Color borderColor = widget.darkTheme ? Colors.white24 : Colors.black12;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: textColor),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: widget.currentNeighborhood == 'Other' ? 'Search anywhere in Cairo...' : 'Search inside ${widget.currentNeighborhood}...',
              hintStyle: TextStyle(color: hintColor),
              filled: true,
              fillColor: fillColor,
              suffixIcon: _isSearching
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
                  : Icon(Icons.search, color: iconColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
        Stack(
          children: [
            Container(
              height: 250,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              // --- APP UPDATE: RepaintBoundary Isolates Heavy Map Rendering ---
              child: RepaintBoundary(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition,
                    initialZoom: 14.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _currentPosition = point;
                        _suggestions = [];
                      });
                      FocusScope.of(context).unfocus();
                      widget.onLocationSelected(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.aastmt.campuspool',
                    ),
                    MarkerLayer(
                      markers: [
                        // Red pin = pickup location (user's pin)
                        Marker(
                          point: _currentPosition,
                          width: 50,
                          height: 52,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, color: Colors.redAccent, size: 36),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Pickup', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        // Blue pin = driver location (optional)
                        if (widget.showDriverPin && widget.driverLocation != null)
                          Marker(
                            point: widget.driverLocation!,
                            width: 50,
                            height: 52,
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_car, color: Colors.blueAccent, size: 36),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Campus', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: "gps_map_btn",
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                    child: _isFetchingLocation
                        ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2))
                        : const Icon(Icons.my_location, color: AppColors.navy),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: "reset_map_btn",
                    backgroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: widget.darkTheme ? Colors.white24 : Colors.transparent)),
                    onPressed: () => _performReset(widget.currentNeighborhood), // NOW USES SMART RESET
                    child: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (_suggestions.isNotEmpty)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: dropdownBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.2), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: borderColor),
                    itemBuilder: (context, index) {
                      final place = _suggestions[index];
                      final nameParts = place['name'].toString().split(', ');
                      return ListTile(
                        leading: Icon(Icons.location_on, color: hintColor),
                        title: Text(nameParts.first, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: nameParts.length > 1 ? Text(nameParts.sublist(1).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: hintColor, fontSize: 12)) : null,
                        onTap: () => _selectSuggestion(place),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text("Tap map to drop pin, or use search bar", style: TextStyle(fontSize: 12, color: hintColor)),
      ],
    );
  }
}