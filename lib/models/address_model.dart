class AddressModel {
  String id;          // Unique identifier (could be Firestore doc ID)
  String fullAddress;        // Name of the person or organization
  String? street;     // Street or tole name
  String? city;       // City / Municipality
  String? district;   // District
  String? province;   // Province
  String? country;    // Country
  DateTime createdAt;
  double? latitude;   // Optional: for geo-location
  double? longitude;  // Optional: for geo-location

  AddressModel({
    required this.id,
    required this.fullAddress,
    this.city,
    this.district,
    this.province,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  /// Convert Address object to Map (for Firebase or local storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': fullAddress,
      'city': city,
      'district': district,
      'province': province,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Create Address object from Map (e.g., Firestore snapshot)
  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'] ?? '',
      fullAddress: map['name'] ?? '',
      createdAt: DateTime.now(),
      city: map['city'],
      district: map['district'],
      province: map['province'],
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
    );
  }

}
