import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:syriacosmeticsmanger/features/order/domain/models/order_model.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';

class ShowOnMapDialogWidget extends StatelessWidget {
  final BillingAddressData? billingAddressData;

  const ShowOnMapDialogWidget({
    super.key,
    required this.billingAddressData,
  });

  @override
  Widget build(BuildContext context) {
    // 1️⃣ استخراج الإحداثيات مع حماية من الأخطاء
    double? lat;
    double? lng;

    try {
      final latStr = billingAddressData?.latitude?.toString().trim();
      final lngStr = billingAddressData?.longitude?.toString().trim();

      lat = (latStr != null && latStr.isNotEmpty) ? double.tryParse(latStr) : null;
      lng = (lngStr != null && lngStr.isNotEmpty) ? double.tryParse(lngStr) : null;
    } catch (e) {
      lat = null;
      lng = null;
    }

    // 2️⃣ إذا الإحداثيات غير صحيحة، نعرض رسالة بدلاً من خريطة فاضية
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                getTranslated('no_location_available', context) ??
                    'لا تتوفر إحداثيات صحيحة لهذا العنوان',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(getTranslated('close', context) ?? 'إغلاق'),
              ),
            ],
          ),
        ),
      );
    }

    // 3️⃣ عرض الخريطة مع flutter_map
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
      ),
      child: SizedBox(
        height: 450,
        width: MediaQuery.of(context).size.width * 0.95,
        child: Column(
          children: [
            // Header مع العنوان وزر الإغلاق
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
                vertical: Dimensions.paddingSizeSmall,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      billingAddressData?.address ??
                          getTranslated('location', context) ??
                          'الموقع',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // 4️⃣ الخريطة نفسها
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 15.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    // طبقة الخريطة (OpenStreetMap - مجاني 100%)
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sixvalley.seller',
                    ),

                    // Marker (الدبوس الأحمر على الموقع)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lng),
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer مع معلومات الإحداثيات
            Container(
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'OpenStreetMap | ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}