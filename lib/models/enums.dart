enum UserType {
  organization,
  vehicleOwner,
  external,
  system,
}
extension UserTypeExtension on UserType {
  String get label {
    switch (this) {
      case UserType.system:
        return 'System';
      case UserType.vehicleOwner:
        return 'Vehicle Owner';
      case UserType.organization:
        return 'Organization';
      case UserType.external:
        return 'External';
    }
  }
}

enum UserRole {
  driver,
  supervisor,
  accountant,
  manager,
  admin,
}
extension UserRoleExtension on UserRole {
  String get value => name;

  String get label {
    switch (this) {
      case UserRole.driver:
        return 'Driver';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.manager:
        return 'Manager';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

enum UserStatus {
  active,
  inactive,
  blocked,
}

enum ActivityStatus {
  pending,
  running,
  paused,
  completed,
  cancelled,
}

enum VehicleStatus {
  available,
  assigned,
  working,
  maintenance,
  inactive,
}

enum Service {
  rotavator,
  cultivator,
  thresher,
  landLeveler,
  zeroTillSeeder,
  harvester,
}
extension ServiceExtension on Service {
  String get displayName {
    switch (this) {
      case Service.rotavator:
        return 'Rotavator';
      case Service.cultivator:
        return 'Cultivator';
      case Service.thresher:
        return 'Thresher';
      case Service.landLeveler:
        return 'Land Leveler';
      case Service.zeroTillSeeder:
        return 'Zero Till Seeder';
      case Service.harvester:
        return 'Track Harvester';
    }
  }
}
enum ServiceUnit {
  hour,
  kattha,
}
extension ServiceUnitExtension on ServiceUnit {
  String get displayName {
    switch (this) {
      case ServiceUnit.hour:
        return 'Per Hour';
      case ServiceUnit.kattha:
        return 'Per Kattha';
    }
  }
}
