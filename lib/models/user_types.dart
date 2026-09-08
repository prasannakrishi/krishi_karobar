class UserTypes {
  static const String organization = 'organization';
  static const String external = 'external';
  static const String guest = 'guest';
  static const String system = 'system';

  static const List<String> values = [
    organization,
    external,
    guest,
  ];

  static bool isValid(String? value) {
    return values.contains(value);
  }
}