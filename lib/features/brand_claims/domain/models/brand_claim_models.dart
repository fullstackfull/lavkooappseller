/// Which brands the seller sells under, and where each one stands.
///
/// Read from the seller's own catalogue rather than from the claims table, so
/// the list says something true about their shop: a brand they have never
/// listed under does not appear, however many claims exist for it.
class BrandExposureModel {
  final int brandId;
  final String? brandName;
  final int products;

  /// The seller's own claim on this brand, if they have made one. Null means
  /// they have not — which is not a problem while `mayList` is true.
  final String? claimStatus;

  final bool mayList;

  const BrandExposureModel({
    required this.brandId,
    required this.products,
    required this.mayList,
    this.brandName,
    this.claimStatus,
  });

  bool get needsAction => !mayList;

  static BrandExposureModel fromJson(Map<String, dynamic> json) => BrandExposureModel(
        brandId: _int(json['brand_id']),
        brandName: json['brand_name']?.toString(),
        products: _int(json['products']),
        claimStatus: json['claim_status']?.toString(),
        mayList: json['may_list'] == true,
      );
}

/// One claim, and where a person got to with it.
class BrandClaimModel {
  final int id;
  final int brandId;
  final String? brandName;
  final String claimType;
  final String status;
  final String? statement;
  final bool isEditable;
  final bool isPending;

  /// Whether this claim currently entitles the seller to list under the brand.
  /// Not the same as `status == 'approved'` — an approval can have run out.
  final bool entitles;

  final String? reviewNote;
  final String? expiresAt;
  final List<BrandClaimDocumentModel> documents;

  const BrandClaimModel({
    required this.id,
    required this.brandId,
    required this.claimType,
    required this.status,
    required this.isEditable,
    required this.isPending,
    required this.entitles,
    required this.documents,
    this.brandName,
    this.statement,
    this.reviewNote,
    this.expiresAt,
  });

  static BrandClaimModel fromJson(Map<String, dynamic> json) => BrandClaimModel(
        id: _int(json['id']),
        brandId: _int(json['brand_id']),
        brandName: json['brand_name']?.toString(),
        claimType: json['claim_type']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        statement: json['statement']?.toString(),
        isEditable: json['is_editable'] == true,
        isPending: json['is_pending'] == true,
        entitles: json['entitles'] == true,
        reviewNote: json['review_note']?.toString(),
        expiresAt: json['expires_at']?.toString(),
        documents: (json['documents'] as List?)
                ?.whereType<Map>()
                .map((e) => BrandClaimDocumentModel.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const <BrandClaimDocumentModel>[],
      );
}

class BrandClaimDocumentModel {
  final int id;
  final String documentType;
  final String? originalName;
  final String? expiresAt;

  const BrandClaimDocumentModel({
    required this.id,
    required this.documentType,
    this.originalName,
    this.expiresAt,
  });

  static BrandClaimDocumentModel fromJson(Map<String, dynamic> json) => BrandClaimDocumentModel(
        id: _int(json['id']),
        documentType: json['document_type']?.toString() ?? '',
        originalName: json['original_name']?.toString(),
        expiresAt: json['expires_at']?.toString(),
      );
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
