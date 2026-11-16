class VoiceNoteMetadata {
  const VoiceNoteMetadata({
    required this.id,
    required this.durationMs,
    required this.sizeBytes,
  });
  final String id;
  final int durationMs;
  final int sizeBytes;
  Duration get duration => Duration(milliseconds: durationMs);
  static VoiceNoteMetadata? parse(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final duration = value['durationMs'];
    final size = value['sizeBytes'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 64 ||
        duration is! int ||
        duration <= 0 ||
        duration > 60000 ||
        size is! int ||
        size < 44 ||
        size > 2097152 ||
        value['contentType'] != 'audio/wav')
      return null;
    return VoiceNoteMetadata(id: id, durationMs: duration, sizeBytes: size);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'durationMs': durationMs,
    'sizeBytes': sizeBytes,
    'contentType': 'audio/wav',
  };
}
