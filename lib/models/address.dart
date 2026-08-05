/// نموذج عنوان التوصيل
class Address {
  final String id;
  final String userId;
  final String label;
  final String fullName;
  final String phone;
  final String street;
  final String district;
  final String city;
  final String state;
  final String? landmark;
  final String? additionalDetails;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.fullName,
    required this.phone,
    required this.street,
    required this.district,
    required this.city,
    this.state = 'أمانة العاصمة',
    this.landmark,
    this.additionalDetails,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  String get fullAddress =>
      '$street، $district، $city، $state';

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      label: map['label'] ?? 'منزلي',
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      street: map['street'] ?? '',
      district: map['district'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? 'أمانة العاصمة',
      landmark: map['landmark'],
      additionalDetails: map['additionalDetails'],
      isDefault: map['isDefault'] ?? false,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'label': label,
      'fullName': fullName,
      'phone': phone,
      'street': street,
      'district': district,
      'city': city,
      'state': state,
      'landmark': landmark,
      'additionalDetails': additionalDetails,
      'isDefault': isDefault,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Address copyWith({
    String? id,
    String? userId,
    String? label,
    String? fullName,
    String? phone,
    String? street,
    String? district,
    String? city,
    String? state,
    String? landmark,
    String? additionalDetails,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      street: street ?? this.street,
      district: district ?? this.district,
      city: city ?? this.city,
      state: state ?? this.state,
      landmark: landmark ?? this.landmark,
      additionalDetails: additionalDetails ?? this.additionalDetails,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
