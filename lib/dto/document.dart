class Document {
  final String? documentName;
  final String documentType;
  final String tourSalesUuid;
  final bool visibleToAll;

  Document({required this.documentName, required this.documentType, required this.tourSalesUuid, required this.visibleToAll});

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      documentName: json['documentName'],
      documentType: json['documentType'],
      tourSalesUuid: json['tourSalesUuid'],
      visibleToAll: json['visibleToAll'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'documentName': documentName, 'documentType': documentType, 'tourSalesUuid': tourSalesUuid, 'visibleToAll': visibleToAll};
  }
}
