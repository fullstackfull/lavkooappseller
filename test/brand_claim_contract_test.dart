import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/brand_claims/domain/models/brand_claim_models.dart';

/// Captured from a running backend
/// (`/api/v3/seller/seller-center/brand-claims/...`).
///
/// The state this marketplace is actually in is the first case below: brands
/// exist, listings carry them, and nobody has claimed anything — so `may_list`
/// is true everywhere and the screen must not invent a problem. That is the
/// whole reason enforcement ships switched off, and a client that treated
/// "no claim" as "not allowed" would undo it.
void main() {
  const String liveExposure = '''
  {"enforcing":false,"brands":[
    {"brand_id":10,"brand_name":"Medi","products":4,"claim_status":null,"may_list":true}]}''';

  const String contestedExposure = '''
  {"enforcing":false,"brands":[
    {"brand_id":10,"brand_name":"Medi","products":4,"claim_status":null,"may_list":false},
    {"brand_id":11,"brand_name":"Other","products":1,"claim_status":"approved","may_list":true}]}''';

  const String liveClaim = '''
  {"id":1,"brand_id":10,"brand_name":"Medi","claim_type":"authorized_reseller",
   "status":"submitted","statement":"We buy direct from the importer.",
   "is_editable":false,"is_pending":true,"entitles":false,
   "submitted_at":"2026-08-24T09:00:00.000000Z","reviewed_at":null,"review_note":null,
   "expires_at":"2027-01-31T00:00:00.000000Z",
   "documents":[{"id":3,"document_type":"authorization_letter","original_name":"letter.pdf",
     "reference":"AL-2026-11","expires_at":"2027-01-31T00:00:00.000000Z",
     "created_at":"2026-08-24T08:59:00.000000Z"}]}''';

  test('a brand nobody has claimed is not a problem', () {
    final Map<String, dynamic> json = jsonDecode(liveExposure) as Map<String, dynamic>;
    final BrandExposureModel brand =
        BrandExposureModel.fromJson(Map<String, dynamic>.from((json['brands'] as List).first as Map));

    expect(json['enforcing'], isFalse);
    expect(brand.claimStatus, isNull);
    // No claim and no problem. Treating a null claim as "not allowed" would put
    // a warning on every brand in a marketplace where nothing is claimed yet.
    expect(brand.mayList, isTrue);
    expect(brand.needsAction, isFalse);
  });

  test('needing action is the server\'s answer, not the absence of a claim', () {
    final List brands = (jsonDecode(contestedExposure) as Map)['brands'] as List;
    final List<BrandExposureModel> parsed = brands
        .map((e) => BrandExposureModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    // The first has no claim and is a problem; the second has one and is not.
    // Neither could be worked out from `claim_status` alone.
    expect(parsed.first.claimStatus, isNull);
    expect(parsed.first.needsAction, isTrue);
    expect(parsed.last.claimStatus, 'approved');
    expect(parsed.last.needsAction, isFalse);
  });

  test('a claim with the marketplace is not editable and entitles nothing yet', () {
    final BrandClaimModel claim =
        BrandClaimModel.fromJson(jsonDecode(liveClaim) as Map<String, dynamic>);

    expect(claim.status, 'submitted');
    expect(claim.isPending, isTrue);
    expect(claim.isEditable, isFalse);
    // Uploading paperwork is not the same as somebody having read it.
    expect(claim.entitles, isFalse);
    expect(claim.documents.single.documentType, 'authorization_letter');
  });

  test('an approval that has run out does not entitle, whatever its status says', () {
    final BrandClaimModel claim = BrandClaimModel.fromJson(jsonDecode('''
      {"id":2,"brand_id":10,"brand_name":"Medi","claim_type":"authorized_reseller",
       "status":"approved","statement":null,"is_editable":false,"is_pending":false,
       "entitles":false,"submitted_at":"2026-01-01T00:00:00.000000Z",
       "reviewed_at":"2026-01-02T00:00:00.000000Z","review_note":"Letter accepted",
       "expires_at":"2026-06-01T00:00:00.000000Z","documents":[]}''') as Map<String, dynamic>);

    expect(claim.status, 'approved');
    // The server decides this, and the two disagree on purpose: a lapsed letter
    // of authority is still an approval that happened, and no longer a licence.
    expect(claim.entitles, isFalse);
  });

  test('a rejected claim carries the reason and is editable again', () {
    final BrandClaimModel claim = BrandClaimModel.fromJson(jsonDecode('''
      {"id":4,"brand_id":10,"brand_name":"Medi","claim_type":"owner","statement":"Ours",
       "status":"rejected","is_editable":true,"is_pending":false,"entitles":false,
       "submitted_at":"2026-08-01T00:00:00.000000Z","reviewed_at":"2026-08-02T00:00:00.000000Z",
       "review_note":"The certificate is for a different class.","expires_at":null,
       "documents":[]}''') as Map<String, dynamic>);

    expect(claim.isEditable, isTrue);
    expect(claim.reviewNote, 'The certificate is for a different class.');
  });

  test('a claim with no documents reads as empty rather than missing', () {
    final BrandClaimModel claim = BrandClaimModel.fromJson(jsonDecode('''
      {"id":5,"brand_id":11,"claim_type":"owner","status":"draft","is_editable":true,
       "is_pending":false,"entitles":false,"documents":[]}''') as Map<String, dynamic>);

    expect(claim.documents, isEmpty);
    expect(claim.brandName, isNull);
  });
}
