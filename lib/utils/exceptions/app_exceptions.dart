import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

/// Base class for every classified application error.
///
/// [message] is the user-facing text and is always safe to show in a
/// snackbar/dialog. [code] and [details] hold the technical reason and are
/// meant for debug logs only.
abstract class AppException implements Exception {
  const AppException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  static const String genericMessage =
      'Unable to complete the request. Please try again.';

  /// User-facing message for any error object.
  static String messageOf(Object? error) {
    if (error == null) return genericMessage;
    if (error is AppException) return error.message;
    return from(error).message;
  }

  /// Classifies a raw error into the matching [AppException] category.
  static AppException from(
    Object error, {
    String? operation,
    String? path,
  }) {
    if (error is AppException) return error;

    final details = _details(error, operation, path);

    if (error is FirebaseException) {
      final code = error.code.trim().toLowerCase();
      final text = (error.message ?? '').toLowerCase();

      if (error.plugin == 'firebase_auth') {
        return AuthenticationException.required(
          code: code,
          details: details,
        );
      }

      if (code.contains('permission') || text.contains('permission denied')) {
        return AuthorizationException.dataAccess(
          code: code,
          details: details,
        );
      }

      if (code == 'unauthenticated' ||
          code == 'expired-token' ||
          code == 'invalid-token' ||
          text.contains('unauthenticated')) {
        return AuthenticationException.required(
          code: code,
          details: details,
        );
      }

      if (code == 'network-error' ||
          code == 'unavailable' ||
          code == 'disconnected' ||
          code == 'network-request-failed') {
        return NetworkException(code: code, details: details);
      }

      if (code == 'not-found') {
        return RecordNotFoundException(code: code, details: details);
      }

      return FirebaseOperationException(code: code, details: details);
    }

    if (error is PlatformException) {
      final code = error.code.trim().toLowerCase();

      if (code.contains('permission')) {
        return AuthorizationException.dataAccess(
          code: code,
          details: details,
        );
      }

      if (code.contains('network')) {
        return NetworkException(code: code, details: details);
      }

      return FirebaseOperationException(code: code, details: details);
    }

    final text = error.toString().toLowerCase();

    if (error is TimeoutException ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable')) {
      return NetworkException(
        code: 'network-unreachable',
        details: details,
      );
    }

    if (error is FormatException || error is TypeError) {
      return DataValidationException(
        code: 'invalid-data',
        details: details,
      );
    }

    return FirebaseOperationException(
      code: 'unknown',
      details: details,
    );
  }

  static String _details(Object error, String? operation, String? path) {
    final buffer = StringBuffer();

    if (operation != null) buffer.write('$operation ');
    if (path != null) buffer.write('[$path] ');

    buffer.write(error.toString());

    return buffer.toString();
  }

  @override
  String toString() {
    final reason = details == null ? '' : ' | $details';
    return '$runtimeType(${code ?? '-'}): $message$reason';
  }
}

/// Not signed in, session expired, or the account cannot be used.
class AuthenticationException extends AppException {
  const AuthenticationException(
    super.message, {
    super.code,
    super.details,
  });

  const AuthenticationException.required({String? code, Object? details})
      : this(
          'Authentication required. Please sign in again.',
          code: code ?? 'unauthenticated',
          details: details,
        );

  const AuthenticationException.inactiveAccount({Object? details})
      : this(
          'Your account is inactive. Please contact the administrator.',
          code: 'account-inactive',
          details: details,
        );

  const AuthenticationException.suspendedAccount({Object? details})
      : this(
          'Your account has been suspended. Please contact the administrator.',
          code: 'account-suspended',
          details: details,
        );

  const AuthenticationException.profileNotLinked({Object? details})
      : this(
          'Your account is not linked to a user profile. '
          'Please contact the administrator.',
          code: 'profile-not-linked',
          details: details,
        );
}

/// The signed-in user lacks the privilege for this operation, or Firebase
/// refused the read/write.
class AuthorizationException extends AppException {
  const AuthorizationException(
    super.message, {
    super.code,
    super.details,
  });

  const AuthorizationException.permission({String? code, Object? details})
      : this(
          "You don't have permission to perform this action.",
          code: code ?? 'permission-required',
          details: details,
        );

  const AuthorizationException.dataAccess({String? code, Object? details})
      : this(
          "Access denied. You don't have permission to access this data.",
          code: code ?? 'permission-denied',
          details: details,
        );
}

/// The user holds the privilege but not for this particular record.
class RecordAccessException extends AppException {
  const RecordAccessException({String? code, Object? details})
      : super(
          "You don't have access to this record.",
          code: code ?? 'record-access-denied',
          details: details,
        );
}

/// Stored/incoming data could not be validated or parsed into a model.
class DataValidationException extends AppException {
  const DataValidationException({String? message, String? code, Object? details})
      : super(
          message ??
              'The data format is invalid. '
                  'Please check the information and try again.',
          code: code ?? 'invalid-data',
          details: details,
        );
}

/// The requested record does not exist.
class RecordNotFoundException extends AppException {
  const RecordNotFoundException({String? code, Object? details})
      : super(
          'The requested record was not found.',
          code: code ?? 'not-found',
          details: details,
        );
}

/// Connectivity failure.
class NetworkException extends AppException {
  const NetworkException({String? code, Object? details})
      : super(
          'Network error. Please check your internet connection and try again.',
          code: code ?? 'network-error',
          details: details,
        );
}

/// GPS/Location services exception.
class LocationException extends AppException {
  const LocationException(
    super.message, {
    super.code,
    super.details,
  });

  const LocationException.permissionDenied({Object? details})
      : this(
          'Location permission denied. Please grant location permission to proceed.',
          code: 'permission-denied',
          details: details,
        );

  const LocationException.permissionPermanentlyDenied({Object? details})
      : this(
          'Location permission permanently denied. Please enable location permissions in device settings.',
          code: 'permission-permanently-denied',
          details: details,
        );

  const LocationException.serviceDisabled({Object? details})
      : this(
          'Location service is disabled. Please enable GPS/location on your device.',
          code: 'service-disabled',
          details: details,
        );

  const LocationException.acquisitionFailed({String? message, Object? details})
      : this(
          message ?? 'Failed to acquire GPS location. Please try again.',
          code: 'acquisition-failed',
          details: details,
        );

  LocationException.poorAccuracy({double? accuracy, Object? details})
      : super(
          'Location accuracy is too poor${accuracy != null ? ' (${accuracy.toStringAsFixed(1)}m)' : ''}. Please move to an open area with clear sky view.',
          code: 'poor-accuracy',
          details: details,
        );
}

/// Any other Firebase/server failure.
class FirebaseOperationException extends AppException {
  const FirebaseOperationException({String? code, Object? details})
      : super(
          AppException.genericMessage,
          code: code ?? 'operation-failed',
          details: details,
        );
}
