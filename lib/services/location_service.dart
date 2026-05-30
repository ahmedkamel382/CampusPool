import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationService {
  // For exact searches (pressing Enter)
  static Future<LatLng?> searchLocation(String query, {String? searchContext}) async {
    String cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    // Append the neighborhood context if it exists cleanly
    String finalQuery = searchContext != null ? "$cleanQuery, $searchContext" : cleanQuery;
    final encodedQuery = Uri.encodeComponent(finalQuery);

    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1&addressdetails=1&countrycodes=eg');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'CampusPool_App'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
        }
      }
    } catch (e) {
      debugPrint("Search Error: $e");
    }
    return null;
  }

  // For live Autocomplete Suggestions
  static Future<List<Map<String, dynamic>>> getSuggestions(String query, {String? searchContext}) async {
    String cleanQuery = query.trim();

    // Prevent searching if the trimmed text is too short
    if (cleanQuery.length < 3) return [];

    // Append the neighborhood context cleanly
    String finalQuery = searchContext != null ? "$cleanQuery, $searchContext" : cleanQuery;
    final encodedQuery = Uri.encodeComponent(finalQuery);

    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5&addressdetails=1&countrycodes=eg');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'CampusPool_App'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((place) => {
          'name': place['display_name'],
          'lat': double.parse(place['lat']),
          'lon': double.parse(place['lon']),
        }).toList();
      }
    } catch (e) {
      debugPrint("Suggestion Error: $e");
    }
    return [];
  }
}