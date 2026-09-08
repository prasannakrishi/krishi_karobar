class UserRoles {
  static const String superAdmin = 'super_admin';
  static const String admin = 'admin';
  static const String manager = 'manager';
  static const String accountant = 'accountant';
  static const String driver = 'driver';
  static const String supervisor = 'supervisor';

  static const List<String> values = [
    superAdmin,
    admin,
    manager,
    accountant,
    driver,
    supervisor,
  ];

  static bool isValid(String value) {
    return values.contains(value);
  }
}