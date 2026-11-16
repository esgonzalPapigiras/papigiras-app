import 'json_fields.dart';

class Document {
  final String? documentName;
  final String documentType;
  final String tourSalesUuid;
  final bool visibleToAll;

  Document({
    required this.documentName,
    required this.documentType,
    required this.tourSalesUuid,
    required this.visibleToAll,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      documentName: JsonFields.text(json['documentName']),
      documentType: JsonFields.text(json['documentType']),
      tourSalesUuid: JsonFields.text(json['tourSalesUuid']),
      visibleToAll: JsonFields.boolean(json['visibleToAll']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentName': documentName,
      'documentType': documentType,
      'tourSalesUuid': tourSalesUuid,
      'visibleToAll': visibleToAll,
    };
  }
}
