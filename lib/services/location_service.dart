import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../utils/exceptions/app_exceptions.dart';
import 'firebase_service.dart';

/// GPS Location service for capturing, validating, saving, and launching maps
/// for Activity Start/Stop GPS locations.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static LocationService get instance => _instance;

  final FirebaseService _firebaseService = FirebaseService();

  static final Map<String, String> _addressCache = {};

  /// Maximum acceptable horizontal accuracy in meters (e.g. 100m).
  static const double maxAcceptableAccuracyMeters = 100.0;

  /// Captures current device location, validating location permissions, service state,
  /// acquisition success, and horizontal accuracy.
  Future<ActivityLocationModel> captureCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException.serviceDisabled();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException.permissionDenied();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException.permissionPermanentlyDenied();
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      debugPrint('LocationService.getCurrentPosition failed: $e');
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      if (position == null) {
        throw LocationException.acquisitionFailed(details: e.toString());
      }
    }

    if (position.accuracy > maxAcceptableAccuracyMeters) {
      throw LocationException.poorAccuracy(accuracy: position.accuracy);
    }

    return ActivityLocationModel(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      capturedAt: DateTime.now(),
    );
  }

  /// Retries capturing start location in the background while the activity is running.
  /// Obtains the first position during activity running time when accuracy is achieved.
  Future<ActivityLocationModel?> captureStartLocationWithRetry({
    int maxRetries = 6,
    Duration retryInterval = const Duration(seconds: 3),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final loc = await captureCurrentLocation();
        return loc;
      } catch (e) {
        debugPrint('LocationService start retry ${i + 1}/$maxRetries: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(retryInterval);
        } else {
          try {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 5),
              ),
            );
            return ActivityLocationModel(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              capturedAt: DateTime.now(),
            );
          } catch (_) {
            rethrow;
          }
        }
      }
    }
    return null;
  }

  /// Performs reverse geocoding to retrieve place name / location address from coordinates.
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final key =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (_addressCache.containsKey(key)) {
      return _addressCache[key]!;
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=14&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'KrishiKarobarApp/1.0',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['address'] is Map) {
          final address = Map<String, dynamic>.from(data['address'] as Map);
          final placeName = address['suburb'] ??
              address['village'] ??
              address['town'] ??
              address['city_district'] ??
              address['city'] ??
              address['county'] ??
              address['state'] ??
              '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

          final country = address['country']?.toString() ?? '';
          final formatted = country.isNotEmpty
              ? '$placeName, $country'
              : placeName.toString();
          _addressCache[key] = formatted;
          return formatted;
        }
      }
    } catch (e) {
      debugPrint('LocationService.getAddressFromCoordinates error: $e');
    }

    final fallback =
        '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    _addressCache[key] = fallback;
    return fallback;
  }

  /// Saves the Start GPS location object to `activity_locations/$activityId`.
  Future<void> saveStartLocation(
    String activityId,
    ActivityLocationModel startLoc,
  ) async {
    await _firebaseService.updateRecord(
      'activity_locations',
      activityId,
      {
        'id': activityId,
        'startLocation': startLoc.toMap(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Saves the Stop GPS location object to `activity_locations/$activityId`.
  Future<void> saveStopLocation(
    String activityId,
    ActivityLocationModel stopLoc,
  ) async {
    await _firebaseService.updateRecord(
      'activity_locations',
      activityId,
      {
        'id': activityId,
        'stopLocation': stopLoc.toMap(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Fetches saved locations for [activityId] from `activity_locations`.
  Future<Map<String, dynamic>?> getActivityLocations(String activityId) async {
    return await _firebaseService.getRecordById(
      'activity_locations',
      activityId,
    );
  }

  /// Opens Google Maps navigation/viewing for the specified coordinates.
  Future<bool> openMap(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('LocationService.openMap error: $e');
      return false;
    }
  }
}
