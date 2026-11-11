/// The seller's KYC standing, as `GET /api/v3/seller/seller-center/verification`
/// returns it. Admin review internals are never sent, so a document reports
/// [hasFile] instead of a storage path.
class VerificationStatusModel {
  final String overallStatus;
  final bool kycRequiredForPayout;
  final List<String> requiredDocuments;
  final List<VerificationDocumentModel> documents;

  VerificationStatusModel({
    this.overallStatus = 'unverified',
    this.kycRequiredForPayout = false,
    this.requiredDocuments = const [],
    this.documents = const [],
  });

  factory VerificationStatusModel.fromJson(Map<String, dynamic> json) {
    return VerificationStatusModel(
      overallStatus: json['overall_status'] ?? 'unverified',
      kycRequiredForPayout: json['kyc_required_for_payout'] == true,
      requiredDocuments: json['required_documents'] != null
          ? List<String>.from(json['required_documents'].map((type) => '$type'))
          : const [],
      documents: json['documents'] != null
          ? List<VerificationDocumentModel>.from(
              json['documents'].map((document) => VerificationDocumentModel.fromJson(document)))
          : const [],
    );
  }

  /// The required types with no approved document yet — what the seller still owes.
  List<String> get outstandingDocuments => requiredDocuments
      .where((type) => !documents.any((document) =>
          document.documentType == type && document.status == 'approved'))
      .toList();
}

class VerificationDocumentModel {
  final int? id;
  final String? documentType;
  final String? documentNumber;
  final String status;
  final String? rejectionReason;
  final String? expiresAt;
  final bool hasFile;

  VerificationDocumentModel({
    this.id,
    this.documentType,
    this.documentNumber,
    this.status = 'pending',
    this.rejectionReason,
    this.expiresAt,
    this.hasFile = false,
  });

  factory VerificationDocumentModel.fromJson(Map<String, dynamic> json) {
    return VerificationDocumentModel(
      id: int.tryParse('${json['id']}'),
      documentType: json['document_type'],
      documentNumber: json['document_number'],
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      expiresAt: json['expires_at'],
      hasFile: json['has_file'] == true,
    );
  }
}
