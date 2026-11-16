import '../lab/media_data.dart';

class Responseimagepassenger {
  final String image;

  Responseimagepassenger({required this.image});

  factory Responseimagepassenger.fromJson(Map<String, dynamic> json) {
    return Responseimagepassenger(image: LocalImageData.encoded(json['image']));
  }
}
