import 'package:latlong2/latlong.dart';

class AppLocations {
  // Center of Greater Cairo (Tahrir Square) for out-of-bounds checking
  static const LatLng cairoCenter = LatLng(30.0444, 31.2357);

  // Geofencing Rules
  static const double maxCairoRadiusMeters = 50000; // 50km (Covers Zayed to New Capital)
  static const double neighborhoodRadiusMeters = 8000; // 8km radius per neighborhood

  static const Map<String, LatLng> campusCoordinates = {
    'Engineering/CS': LatLng(30.096193, 31.373611),
    'Business': LatLng(30.096209, 31.379590),
  };

  // Neighborhood Centers (Expanded)
  static const Map<String, LatLng> neighborhoodCoordinates = {
    'Nasr City': LatLng(30.0600, 31.3400),
    'Tagamoa': LatLng(30.0070, 31.4800),
    'Rehab': LatLng(30.0600, 31.4900),
    'Madinaty': LatLng(30.0967, 31.6245),
    'Shorouk': LatLng(30.1419, 31.6360),
    'Obour': LatLng(30.2246, 31.4727),
    'Heliopolis': LatLng(30.0900, 31.3200),
    'Maadi': LatLng(29.9600, 31.2600),
    'Zamalek': LatLng(30.0626, 31.2200),
    'Dokki': LatLng(30.0381, 31.2112),
    'Mohandeseen': LatLng(30.0543, 31.1983),
    'Haram': LatLng(29.9880, 31.1440),
    'Zayed': LatLng(30.0500, 31.0000),
    '6th of October': LatLng(29.9715, 30.9450),
    'New Capital': LatLng(30.0150, 31.7390),
    'Other': LatLng(30.0444, 31.2357), // Defaults to Cairo center
  };

  // Hidden Search Contexts (Expanded)
  static const Map<String, String> osmSearchContext = {
    'Nasr City': 'Nasr City, Cairo',
    'Tagamoa': 'New Cairo, Cairo',
    'Rehab': 'Al Rehab, Cairo',
    'Madinaty': 'Madinaty, Cairo',
    'Shorouk': 'El Shorouk, Cairo',
    'Obour': 'El Obour, Qalyubia',
    'Heliopolis': 'Heliopolis, Cairo',
    'Maadi': 'Maadi, Cairo',
    'Zamalek': 'Zamalek, Cairo',
    'Dokki': 'Dokki, Giza',
    'Mohandeseen': 'Mohandeseen, Giza',
    'Haram': 'Al Haram, Giza',
    'Zayed': 'Sheikh Zayed, Giza',
    '6th of October': '6th of October, Giza',
    'New Capital': 'New Administrative Capital, Cairo',
    'Other': 'Cairo, Egypt', // General fallback search
  };
}