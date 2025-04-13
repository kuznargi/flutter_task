class Course {
  final int id;
  final String header;
  final String illustration;
  final String description;
  final String? deviceId;
  Course({
    required this.id,
    required this.header,
    required this.illustration,
    required this.description,
      this.deviceId,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      header: json['header'],
      illustration: json['illustration'],
      description: json['description'],
      deviceId: json['device_id'],
    );
  }
   Map<String, dynamic> toJson() => {
        'device_id': deviceId, 
      };
}