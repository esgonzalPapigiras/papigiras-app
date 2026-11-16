import 'dart:typed_data';

import 'package:papigiras_app/dto/Itinerary.dart';

const internalDocumentMaxBytes = 10 * 1024 * 1024;
const internalDocumentExtensions = <String>[
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'jpg',
  'jpeg',
  'png',
  'webp',
];

enum InternalDocumentCategory {
  general('GENERAL', 'Generales'),
  voucher('VOUCHER', 'Vouchers');

  const InternalDocumentCategory(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static InternalDocumentCategory fromWire(String value) => switch (value) {
    'GENERAL' => general,
    'VOUCHER' => voucher,
    _ => throw const FormatException('Categoría de documento desconocida.'),
  };
}

class InternalTourDocument {
  const InternalTourDocument({
    required this.id,
    required this.tourId,
    required this.category,
    required this.name,
    required this.originalName,
    required this.storedName,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
    this.activityId,
    this.activityName,
  });
  final String id;
  final int tourId;
  final InternalDocumentCategory category;
  final String name;
  final String originalName;
  final String storedName;
  final String contentType;
  final int sizeBytes;
  final DateTime? createdAt;
  final int? activityId;
  final String? activityName;

  factory InternalTourDocument.fromJson(Map<String, dynamic> json) =>
      InternalTourDocument(
        id: json['id'] as String,
        tourId: (json['tourId'] as num).toInt(),
        category: InternalDocumentCategory.fromWire(json['category'] as String),
        name: json['name'] as String,
        originalName: json['originalName'] as String,
        storedName: json['storedName'] as String,
        contentType: json['contentType'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        activityId: (json['activityId'] as num?)?.toInt(),
        activityName: json['activityName'] as String?,
      );

  bool get canPreview =>
      contentType == 'application/pdf' ||
      const {'image/jpeg', 'image/png', 'image/webp'}.contains(contentType);
}

class InternalDocumentFile {
  const InternalDocumentFile({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });
  final String fileName;
  final String contentType;
  final Uint8List bytes;
  int get sizeBytes => bytes.length;
}

class InternalDocumentDownload extends InternalDocumentFile {
  const InternalDocumentDownload({
    required super.fileName,
    required super.contentType,
    required super.bytes,
  });
}

class InternalDocumentValidationException implements Exception {
  const InternalDocumentValidationException(this.message);
  final String message;
}

void validateInternalDocumentFile(InternalDocumentFile file) {
  final extension = file.fileName.split('.').last.toLowerCase();
  if (!internalDocumentExtensions.contains(extension)) {
    throw const InternalDocumentValidationException(
      'Elige un PDF, Word, Excel o una imagen JPG, PNG o WEBP.',
    );
  }
  if (file.bytes.isEmpty) {
    throw const InternalDocumentValidationException(
      'El archivo está vacío. Elige otro.',
    );
  }
  if (file.sizeBytes > internalDocumentMaxBytes) {
    throw const InternalDocumentValidationException(
      'El archivo supera los 10 MB. Elige uno más pequeño.',
    );
  }
}

String internalDocumentMime(String extension) => switch (extension
    .toLowerCase()) {
  'pdf' => 'application/pdf',
  'doc' => 'application/msword',
  'docx' =>
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls' => 'application/vnd.ms-excel',
  'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  _ => throw const InternalDocumentValidationException(
    'Este tipo de archivo no está permitido.',
  ),
};

/// Private tour documents. Implementations preserve server authorization and
/// never merge these records into the existing family-visible document API.
abstract interface class InternalDocumentsRepository {
  Future<List<InternalTourDocument>> listInternalDocuments(int tourId);
  Future<List<Itinerary>> getInternalDocumentActivities(int tourId);
  Future<InternalTourDocument> uploadInternalDocument({
    required int tourId,
    required String name,
    required InternalDocumentCategory category,
    int? activityId,
    required InternalDocumentFile file,
    void Function(double progress)? onProgress,
  });
  Future<InternalDocumentDownload> downloadInternalDocument({
    required int tourId,
    required String documentId,
  });
}
