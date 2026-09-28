import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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
    return await _firebaseService.getRecordById('activity_locations', activityId);
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
