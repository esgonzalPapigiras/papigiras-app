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

  // Método para crear una instancia de Document desde un JSON
  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      documentName: json['documentName'],
      documentType: json['documentType'],
      tourSalesUuid: json['tourSalesUuid'],
      visibleToAll: json['visibleToAll'] ?? false,
    );
  }

  // Método para convertir una instancia de Document a JSON
  Map<String, dynamic> toJson() {
    return {
      'documentName': documentName,
      'documentType': documentType,
      'tourSalesUuid': tourSalesUuid,
      'visibleToAll': visibleToAll,
    };
  }
}
