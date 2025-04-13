class User {
  final String name;
  final int age;
  final String deviceId;

  User({
    required this.name,
    required this.age,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'device_id': deviceId,
  };
}