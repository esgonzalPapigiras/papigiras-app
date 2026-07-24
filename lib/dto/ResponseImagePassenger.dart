class Responseimagepassenger {
  final String image;

  Responseimagepassenger({required this.image});

  factory Responseimagepassenger.fromJson(Map<String, dynamic> json) {
    return Responseimagepassenger(image: json['image'] ?? '');
  }
}
