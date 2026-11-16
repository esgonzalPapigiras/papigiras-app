import 'dart:convert';
import '../lab/api_http.dart';
import '../lab/preferences.dart';
import '../lab/session.dart';

class PhotoLikeState {
  final int photoId, hitoId, likeCount;
  final bool likedByMe;
  const PhotoLikeState({
    required this.photoId,
    required this.hitoId,
    required this.likeCount,
    required this.likedByMe,
  });
  factory PhotoLikeState.fromJson(Map<String, dynamic> json) => PhotoLikeState(
    photoId: _positive(json['photoId']),
    hitoId: _positive(json['hitoId']),
    likeCount: _count(json['likeCount']),
    likedByMe: json['likedByMe'] == true,
  );
  PhotoLikeState withLiked(bool liked) => PhotoLikeState(
    photoId: photoId,
    hitoId: hitoId,
    likeCount:
        (likeCount +
                (liked == likedByMe
                    ? 0
                    : liked
                    ? 1
                    : -1))
            .clamp(0, 2147483647),
    likedByMe: liked,
  );
}

class PhotoLikesSnapshot {
  final bool canLike;
  // UI hint only: the server still controls permission after authentication.
  final bool requiresReauthentication;
  final List<PhotoLikeState> photos;
  final Map<int, int> hitoTotals;
  const PhotoLikesSnapshot({
    required this.canLike,
    this.requiresReauthentication = false,
    required this.photos,
    required this.hitoTotals,
  });
}

class PhotoLikeResult {
  final PhotoLikeState photo;
  final int hitoLikeCount;
  const PhotoLikeResult({required this.photo, required this.hitoLikeCount});
}

abstract class PhotoLikesRepository {
  Future<PhotoLikesSnapshot> load(int tourId);
  Future<PhotoLikeResult> setLiked({
    required int tourId,
    required int hitoId,
    required int photoId,
    required bool liked,
  });
}

int _positive(Object? value) {
  if (value is! int || value <= 0)
    throw const FormatException('Identidad de foto inválida');
  return value;
}

int _count(Object? value) {
  if (value is! int || value < 0)
    throw const FormatException('Recuento inválido');
  return value;
}

/// The client uses the same isolated transport and signed-in identity as Pilo.
/// No identity or permission is supplied in the mutation body.
class HttpPhotoLikesRepository implements PhotoLikesRepository {
  final LabApiClient Function() _clientFactory;
  HttpPhotoLikesRepository({LabApiClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? (() => LabApiClient());
  final int _generation = LabSession.generation;
  Future<Map<String, dynamic>> _request(
    int tourId, [
    Map<String, Object>? body,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final expiry = DateTime.tryParse(prefs.getString('tokenExpiry') ?? '');
    if (_generation != LabSession.generation ||
        token.isEmpty ||
        expiry == null ||
        !expiry.isAfter(DateTime.now())) {
      throw const LabApiException(401);
    }
    final client = _clientFactory();
    try {
      final uri = LabApi.uri(
        '/app/services/photo-likes',
        body == null ? {'tourId': '$tourId'} : null,
      );
      final headers = {
        'authorization': token,
        'content-type': 'application/json',
        'accept': 'application/json',
      };
      final response = body == null
          ? await client.get(uri, headers: headers)
          : await client.post(uri, headers: headers, body: jsonEncode(body));
      if (_generation != LabSession.generation)
        throw const LabApiException(401);
      final result = jsonDecode(response.body);
      if (result is! Map<String, dynamic>)
        throw const FormatException('Respuesta de likes inválida');
      return result;
    } finally {
      client.close();
    }
  }

  @override
  Future<PhotoLikesSnapshot> load(int tourId) async {
    final json = await _request(tourId);
    if (json['photos'] is! List ||
        json['hitos'] is! List ||
        json['canLike'] is! bool) {
      throw const FormatException('Respuesta de likes incompleta');
    }
    final prefs = await SharedPreferences.getInstance();
    if (_generation != LabSession.generation) throw const LabApiException(401);
    return PhotoLikesSnapshot(
      requiresReauthentication:
          json['canLike'] == false && prefs.getString('userRole') == 'father',
      canLike: json['canLike'] == true,
      photos: (json['photos'] as List)
          .map(
            (e) => PhotoLikeState.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      hitoTotals: {
        for (final hito in json['hitos'] as List)
          _positive(hito['hitoId']): _count(hito['totalLikes']),
      },
    );
  }

  @override
  Future<PhotoLikeResult> setLiked({
    required int tourId,
    required int hitoId,
    required int photoId,
    required bool liked,
  }) async {
    final json = await _request(tourId, {
      'tourId': tourId,
      'hitoId': hitoId,
      'photoId': photoId,
      'liked': liked,
    });
    return PhotoLikeResult(
      photo: PhotoLikeState.fromJson(json),
      hitoLikeCount: _count(json['hitoLikeCount']),
    );
  }
}
