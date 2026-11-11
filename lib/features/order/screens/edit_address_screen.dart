import 'dart:async';
import 'dart:convert';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as latlng2;
import 'package:syriacosmeticsmanger/features/order/domain/models/geo_point.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/auth/widgets/code_picker_widget.dart';
import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
import 'package:syriacosmeticsmanger/helper/country_code_helper.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/location_controller.dart';
import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
import 'package:syriacosmeticsmanger/features/order/screens/select_location_screen.dart';


class EditAddressScreen extends StatefulWidget {
  final bool? isBilling;
  final String? address;
  final String? city;
  final String? zip;
  final String? name;
  final String? number;
  final String? email;
  final String? orderId;
  final String? lat;
  final String? lng;

  const EditAddressScreen({
    super.key,
    this.isBilling,
    this.address,
    this.city,
    this.zip,
    this.name,
    this.number,
    this.orderId,
    this.email,
    this.lat,
    this.lng,
  });

  @override
  State<EditAddressScreen> createState() => EditAddressScreenState();
}

class EditAddressScreenState extends State<EditAddressScreen> {
  final TextEditingController _contactPersonNameController = TextEditingController();
  final TextEditingController _contactPersonEmailController = TextEditingController();
  final TextEditingController _contactPersonNumberController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();

  final FocusNode _addressNode = FocusNode();
  final FocusNode _nameNode = FocusNode();
  final FocusNode _emailNode = FocusNode();
  final FocusNode _numberNode = FocusNode();
  final FocusNode _cityNode = FocusNode();
  final FocusNode _zipNode = FocusNode();

  bool _updateAddress = true;
  bool _isManualTextChange = false;

  // 👇 متغيرات جديدة للبحث عن العنوان
  Timer? _debounceTimer;
  bool _isSearching = false;

  final fm.MapController _mapController = fm.MapController();

  String? _newLat;
  String? _newLng;

  String? _countryDialCode = "+880";
  String? _phoneNumberOnly;

  @override
  void initState() {
    super.initState();

    if (widget.number != null) {
      String countryCode = CountryCodeHelper.getCountryCode(widget.number)!;
      _countryDialCode = countryCode;
      _phoneNumberOnly = CountryCodeHelper.extractPhoneNumber(countryCode, widget.number!);
    }

    _newLat = widget.lat;
    _newLng = widget.lng;

    Provider.of<LocationController>(context, listen: false)
        .locationTextEditingController
        .text = widget.address ?? '';
    _cityController.text = widget.city ?? '';
    _zipCodeController.text = widget.zip ?? '';
    _contactPersonNameController.text = widget.name ?? '';
    _contactPersonNumberController.text = _phoneNumberOnly ?? '';
    _contactPersonEmailController.text = widget.email ?? '';

    Provider.of<LocationController>(context, listen: false).updateInitialPosition(
      latlng2.LatLng(
        double.parse(widget.lat.toString()),
        double.parse(widget.lng.toString()),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // 👇 دالة البحث عن العنوان وتحويله لإحداثيات
  Future<void> _searchAndMoveToAddress(String address) async {
    if (address.trim().isEmpty || _isSearching) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&limit=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SyriaCosmeticsManager/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data != null && data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lng = double.parse(data[0]['lon'].toString());

          if (mounted) {
            setState(() {
              _newLat = lat.toString();
              _newLng = lng.toString();
              _isManualTextChange = true;
            });

            _mapController.move(latlng2.LatLng(lat, lng), 16.0);

            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                setState(() {
                  _isManualTextChange = false;
                });
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في البحث عن العنوان: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // 👇 دالة مع debounce لمنع الاستدعاءات المتكررة
  void _onAddressChanged(String address) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _searchAndMoveToAddress(address);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('update_address', context)),
      body: SingleChildScrollView(
        child: Consumer<OrderController>(
          builder: (context, orderProvider, _) {
            return Consumer<LocationController>(
              builder: (context, locationProvider, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      // 👇 الخريطة
                      Provider.of<SplashController>(context, listen: false)
                          .configModel!
                          .mapApiStatus == 1
                          ? SizedBox(
                        height: MediaQuery.of(context).size.width / 2,
                        width: MediaQuery.of(context).size.width,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              fm.FlutterMap(
                                mapController: _mapController,
                                options: fm.MapOptions(
                                  initialCenter: latlng2.LatLng(
                                    double.parse(widget.lat.toString()),
                                    double.parse(widget.lng.toString()),
                                  ),
                                  initialZoom: 16.0,
                                  minZoom: 3.0,
                                  maxZoom: 18.0,
                                  onTap: (tapPosition, latLng) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (BuildContext context) => SelectLocationScreen(
                                          initialPosition: latlng2.LatLng(
                                            double.parse(_newLat ?? widget.lat ?? '0'),
                                            double.parse(_newLng ?? widget.lng ?? '0'),
                                          ),
                                        ),
                                      ),
                                    ).then((result) {
                                      if (result != null && result is latlng2.LatLng) {
                                        setState(() {
                                          _newLat = result.latitude.toString();
                                          _newLng = result.longitude.toString();
                                          _isManualTextChange = false;
                                          _updateAddress = false;
                                        });

                                        _mapController.move(result, 16.0);

                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          if (mounted && context.mounted) {
                                            locationProvider.updatePosition(
                                              MapCameraPosition(
  target: GeoPoint(latitude: result.latitude, longitude: result.longitude),
                                                zoom: 16,
                                              ),
                                              true,
                                              null,
                                              context,
                                            );

                                            setState(() {
                                              _updateAddress = true;
                                            });
                                          }
                                        });
                                      }
                                    });
                                  },
                                  onPositionChanged: (position, hasGesture) {
                                    if (hasGesture) {
                                      setState(() {
                                        _newLat = position.center.latitude.toString();
                                        _newLng = position.center.longitude.toString();
                                      });

                                      if (_updateAddress && !_isManualTextChange) {
                                        _updateAddress = false;
                                        locationProvider.updatePosition(
                                          MapCameraPosition(
  target: GeoPoint(latitude: 
                                              position.center.latitude, longitude: position.center.longitude,
                                            ),
                                            zoom: position.zoom,
                                          ),
                                          false,
                                          null,
                                          context,
                                        );
                                      }
                                    }
                                  },
                                ),
                                children: [
                                  fm.TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.sixvalley.seller',
                                  ),
                                ],
                              ),

                              // 👇 الدبوس الثابت
                              Container(
                                width: MediaQuery.of(context).size.width,
                                alignment: Alignment.center,
                                height: MediaQuery.of(context).size.height,
                                child: Icon(
                                  Icons.location_on,
                                  size: 40,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),

                              // 👇 زر التكبير
                              Align(
                                alignment: AlignmentDirectional.topEnd,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (BuildContext context) => SelectLocationScreen(
                                          initialPosition: latlng2.LatLng(
                                            double.parse(_newLat ?? widget.lat ?? '0'),
                                            double.parse(_newLng ?? widget.lng ?? '0'),
                                          ),
                                        ),
                                      ),
                                    ).then((result) {
                                      if (result != null && result is latlng2.LatLng) {
                                        setState(() {
                                          _newLat = result.latitude.toString();
                                          _newLng = result.longitude.toString();
                                          _isManualTextChange = false;
                                          _updateAddress = false;
                                        });

                                        _mapController.move(result, 16.0);

                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          if (mounted && context.mounted) {
                                            locationProvider.updatePosition(
                                              MapCameraPosition(
  target: GeoPoint(latitude: result.latitude, longitude: result.longitude),
                                                zoom: 16,
                                              ),
                                              true,
                                              null,
                                              context,
                                            );

                                            setState(() {
                                              _updateAddress = true;
                                            });
                                          }
                                        });
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(Dimensions.paddingSize),
                                    child: Container(
                                      width: 40,
                                      alignment: Alignment.center,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.paddingSizeExtraSmall,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.fullscreen,
                                        size: 30,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // 👇 مؤشر البحث
                              if (_isSearching)
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                          : const SizedBox(),

                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          getTranslated('delivery_address', context)!,
                          style: Theme.of(context).textTheme.displaySmall!.copyWith(
                            color: Theme.of(context).hintColor,
                            fontSize: Dimensions.fontSizeLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      // 👇 حقل العنوان مع البحث التلقائي
                      CustomTextFieldWidget(
                        border: true,
                        hintText: getTranslated('address_line_02', context),
                        textInputType: TextInputType.streetAddress,
                        textInputAction: TextInputAction.next,
                        focusNode: _addressNode,
                        nextNode: _cityNode,
                        controller: locationProvider.locationTextEditingController,
                        onChanged: (value) {
                          setState(() {
                            _isManualTextChange = true;
                          });

                          _onAddressChanged(value);

                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) {
                              setState(() {
                                _isManualTextChange = false;
                              });
                            }
                          });
                        },
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      Text(
                        getTranslated('city', context)!,
                        style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      // 👇 حقل المدينة مع البحث التلقائي
                      CustomTextFieldWidget(
                        border: true,
                        hintText: getTranslated('city', context),
                        textInputType: TextInputType.streetAddress,
                        textInputAction: TextInputAction.next,
                        focusNode: _cityNode,
                        nextNode: _zipNode,
                        controller: _cityController,
                        onChanged: (value) {
                          setState(() {
                            _isManualTextChange = true;
                          });

                          final fullAddress = '${locationProvider.locationTextEditingController.text}, $value';
                          _onAddressChanged(fullAddress);

                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) {
                              setState(() {
                                _isManualTextChange = false;
                              });
                            }
                          });
                        },
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      Text(
                        getTranslated('zip', context)!,
                        style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      CustomTextFieldWidget(
                        border: true,
                        hintText: getTranslated('zip', context),
                        textInputAction: TextInputAction.next,
                        focusNode: _zipNode,
                        nextNode: _nameNode,
                        controller: _zipCodeController,
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      Text(
                        getTranslated('contact_person_name', context)!,
                        style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      CustomTextFieldWidget(
                        border: true,
                        hintText: getTranslated('enter_contact_person_name', context),
                        textInputType: TextInputType.name,
                        controller: _contactPersonNameController,
                        focusNode: _nameNode,
                        nextNode: _emailNode,
                        textInputAction: TextInputAction.next,
                        capitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      Text(
                        getTranslated('contact_person_number', context)!,
                        style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeSmall),

                      Row(
                        children: [
                          CodePickerWidget(
                            onChanged: (CountryCode countryCode) {
                              _countryDialCode = countryCode.dialCode;
                            },
                            initialSelection: _countryDialCode,
                            favorite: const ['+880'],
                            showDropDownButton: true,
                            padding: EdgeInsets.zero,
                            showFlagMain: true,
                            textStyle: TextStyle(
                              color: Theme.of(context).textTheme.displayLarge!.color,
                            ),
                          ),
                          Expanded(
                            child: CustomTextFieldWidget(
                              border: true,
                              hintText: getTranslated('enter_contact_person_number', context),
                              textInputType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              focusNode: _numberNode,
                              controller: _contactPersonNumberController,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      Container(
                        height: 50.0,
                        margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                        child: orderProvider.isAddressLoading
                            ? const Center(child: CircularProgressIndicator())
                            : CustomButtonWidget(
                          btnTxt: getTranslated('update_address', context),
                          onTap: () {
                            String contactPersonName = _contactPersonNameController.text.trim();
                            String phone = (_countryDialCode ?? '') + _contactPersonNumberController.text.trim();
                            String email = _contactPersonEmailController.text.trim();
                            String city = _cityController.text.trim();
                            String zip = _zipCodeController.text.trim();
                            String addressType = widget.isBilling! ? 'billing' : 'shipping';
                            String address = locationProvider.locationTextEditingController.text.trim();

                            String finalLat = _newLat ?? widget.lat ?? '0';
                            String finalLng = _newLng ?? widget.lng ?? '0';

                            orderProvider.editShippingAndBillingAddress(
                              orderID: widget.orderId,
                              addressType: addressType,
                              contactPersonName: contactPersonName,
                              phone: phone,
                              city: city,
                              zip: zip,
                              address: address,
                              email: email,
                              latitude: finalLat,
                              longitude: finalLng,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

enum Address { shipping, billing }

// import 'package:country_code_picker/country_code_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:provider/provider.dart';
// import 'package:syriacosmeticsmanger/features/auth/widgets/code_picker_widget.dart';
// import 'package:syriacosmeticsmanger/features/splash/controllers/splash_controller.dart';
// import 'package:syriacosmeticsmanger/helper/country_code_helper.dart';
// import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
// import 'package:syriacosmeticsmanger/features/order/controllers/location_controller.dart';
// import 'package:syriacosmeticsmanger/features/order/controllers/order_controller.dart';
// import 'package:syriacosmeticsmanger/utill/dimensions.dart';
// import 'package:syriacosmeticsmanger/utill/styles.dart';
// import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
// import 'package:syriacosmeticsmanger/common/basewidgets/custom_button_widget.dart';
// import 'package:syriacosmeticsmanger/common/basewidgets/textfeild/custom_text_feild_widget.dart';
// import 'package:syriacosmeticsmanger/features/order/screens/select_location_screen.dart';
//
//
// class EditAddressScreen extends StatefulWidget {
//   final bool? isBilling;
//   final String? address;
//   final String? city;
//   final String? zip;
//   final String? name;
//   final String? number;
//   final String? email;
//   final String? orderId;
//   final String? lat;
//   final String? lng;
//
//    const EditAddressScreen({super.key, this.isBilling, this.address, this.city, this.zip, this.name, this.number, this.orderId, this.email, this.lat, this.lng,});
//
//   @override
//   State<EditAddressScreen> createState() => EditAddressScreenState();
// }
//
// class EditAddressScreenState extends State<EditAddressScreen> {
//
//   final TextEditingController _contactPersonNameController = TextEditingController();
//   final TextEditingController _contactPersonEmailController = TextEditingController();
//   final TextEditingController _contactPersonNumberController = TextEditingController();
//   final TextEditingController _cityController = TextEditingController();
//   final TextEditingController _zipCodeController = TextEditingController();
//   final FocusNode _addressNode = FocusNode();
//   final FocusNode _nameNode = FocusNode();
//   final FocusNode _emailNode = FocusNode();
//   final FocusNode _numberNode = FocusNode();
//   final FocusNode _cityNode = FocusNode();
//   final FocusNode _zipNode = FocusNode();
//   bool _updateAddress = true;
//   CameraPosition? _cameraPosition;
//   GoogleMapController? _controller;
//   String? _countryDialCode = "+880";
//   String? _phoneNumberOnly;
//
//   @override
//   void initState() {
//     super.initState();
//
//     if(widget.number != null){
//       String countryCode = CountryCodeHelper.getCountryCode(widget.number)!;
//       _countryDialCode = countryCode;
//       _phoneNumberOnly = CountryCodeHelper.extractPhoneNumber(countryCode, widget.number!);
//     }
//
//
//     Provider.of<LocationController>(context, listen: false).locationTextEditingController.text = widget.address??'';
//     _cityController.text = widget.city??'';
//     _zipCodeController.text = widget.zip??'';
//     _contactPersonNameController.text = widget.name??'';
//     _contactPersonNumberController.text = _phoneNumberOnly??'';
//     _contactPersonEmailController.text = widget.email??'';
//     Provider.of<LocationController>(context, listen: false).updateInitialPosition(LatLng(double.parse(widget.lat.toString()), double.parse(widget.lng.toString())));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: CustomAppBarWidget(title: getTranslated('update_address', context)),
//       body: SingleChildScrollView(
//         child: Consumer<OrderController>(
//           builder: (context, orderProvider,_) {
//             return Consumer<LocationController>(
//               builder: (context, locationProvider,_ ) {
//                 return Container(padding:  const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
//                   child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//
//                     const SizedBox(height: Dimensions.paddingSizeDefault),
//                     Provider.of<SplashController>(context, listen: false).configModel!.mapApiStatus == 1 ?
//                     SizedBox(height: MediaQuery.of(context).size.width/2, width: MediaQuery.of(context).size.width,
//                       child: ClipRRect(borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
//                         child: Stack(clipBehavior: Clip.none, children: [
//                           GoogleMap(mapType: MapType.normal,
//                             initialCameraPosition:  CameraPosition(target: LatLng(double.parse(widget.lat.toString()), double.parse(widget.lng.toString())), zoom: 16),
//                             onTap: (latLng) {
//                              Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) => SelectLocationScreen(googleMapController: _controller)));
//                             },
//                             zoomControlsEnabled: false,
//                             compassEnabled: false,
//                             indoorViewEnabled: true,
//                             mapToolbarEnabled: false,
//                             onCameraMove: ((position) => _cameraPosition = position),
//                             onMapCreated: (GoogleMapController controller) {
//
//                             },
//                             onCameraIdle: () {
//                               if(_updateAddress) {
//                                 locationProvider.updatePosition(_cameraPosition, false, null, context);
//                               }else {
//                                 _updateAddress = true;
//                               }
//                             },
//                           ),
//
//                           Container(width: MediaQuery.of(context).size.width, alignment: Alignment.center,
//                               height: MediaQuery.of(context).size.height,
//                               child: Icon(Icons.location_on, size: 40, color: Theme.of(context).primaryColor,)),
//                           Align(alignment: AlignmentDirectional.topEnd,
//                             child: InkWell(onTap: (){
//                               Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) => SelectLocationScreen(googleMapController: _controller)));
//                             },
//                               child: Padding(padding: const EdgeInsets.all(Dimensions.paddingSize),
//                                 child: Container(width: 40, alignment: Alignment.center,
//                                     height: 40,
//                                     decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(Dimensions.paddingSizeExtraSmall)),
//                                     child: Icon(Icons.fullscreen, size: 30, color: Theme.of(context).primaryColor,)),
//                               )
//                             )
//                           )
//                         ])
//                       ),
//                     ) : const SizedBox(),
//
//                       Padding(padding: const EdgeInsets.only(top: 5),
//                         child: Text(getTranslated('delivery_address', context)!,
//                           style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeLarge))),
//                       const SizedBox(height: Dimensions.paddingSizeSmall),
//
//                       CustomTextFieldWidget(
//                         border: true,
//                         hintText: getTranslated('address_line_02', context),
//                         textInputType: TextInputType.streetAddress,
//                         textInputAction: TextInputAction.next,
//                         focusNode: _addressNode,
//                         nextNode: _cityNode,
//                         controller: locationProvider.locationTextEditingController),
//                       const SizedBox(height: Dimensions.paddingSizeDefault),
//
//                       Text(getTranslated('city', context)!,
//                         style: robotoRegular.copyWith(color: Theme.of(context).hintColor)),
//                       const SizedBox(height: Dimensions.paddingSizeSmall),
//
//                       CustomTextFieldWidget(
//                           border: true,
//                         hintText: getTranslated('city', context),
//                         textInputType: TextInputType.streetAddress,
//                         textInputAction: TextInputAction.next,
//                         focusNode: _cityNode,
//                         nextNode: _zipNode,
//                         controller: _cityController),
//                       const SizedBox(height: Dimensions.paddingSizeDefault),
//
//                       Text(getTranslated('zip', context)!,
//                         style: robotoRegular.copyWith(color: Theme.of(context).hintColor)),
//                       const SizedBox(height: Dimensions.paddingSizeSmall),
//
//                       CustomTextFieldWidget(
//                           border: true,
//                         hintText: getTranslated('zip', context),
//                         textInputAction: TextInputAction.next,
//                         focusNode: _zipNode,
//                         nextNode: _nameNode,
//                         controller: _zipCodeController),
//                       const SizedBox(height: Dimensions.paddingSizeDefault),
//
//                       Text(getTranslated('contact_person_name', context)!,
//                         style: robotoRegular.copyWith(color: Theme.of(context).hintColor)),
//                       const SizedBox(height: Dimensions.paddingSizeSmall),
//
//                     CustomTextFieldWidget(
//                       border: true,
//                         hintText: getTranslated('enter_contact_person_name', context),
//                         textInputType: TextInputType.name,
//                         controller: _contactPersonNameController,
//                         focusNode: _nameNode,
//                         nextNode: _emailNode,
//                         textInputAction: TextInputAction.next,
//                         capitalization: TextCapitalization.words,
//                       ),
//                     const SizedBox(height: Dimensions.paddingSizeDefault),
//
//
//
//                     Text(getTranslated('contact_person_number', context)!,
//                         style: robotoRegular.copyWith(color: Theme.of(context).hintColor)),
//                       const SizedBox(height: Dimensions.paddingSizeSmall),
//
//
//
//
//                     Row(
//                       children: [
//                         CodePickerWidget(
//                           onChanged: (CountryCode countryCode) {
//                            _countryDialCode = countryCode.dialCode;
//                           },
//                           initialSelection: _countryDialCode,
//                           favorite: const ['+880'],
//                           showDropDownButton: true,
//                           padding: EdgeInsets.zero,
//                           showFlagMain: true,
//                           textStyle: TextStyle(color: Theme.of(context).textTheme.displayLarge!.color),
//                         ),
//
//                         Expanded(
//                           child: CustomTextFieldWidget(
//                             border: true,
//                             hintText: getTranslated('enter_contact_person_number', context),
//                             textInputType: TextInputType.phone,
//                             textInputAction: TextInputAction.done,
//                             focusNode: _numberNode,
//                             controller: _contactPersonNumberController,
//                           ),
//                         ),
//
//                       ],
//                     ),
//
//
//                       const SizedBox(height: Dimensions.paddingSizeDefault),
//
//                       Container(height: 50.0,
//                         margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
//                         child: orderProvider.isAddressLoading ? const Center(child: CircularProgressIndicator()) : CustomButtonWidget(
//                           btnTxt: getTranslated('update_address', context),
//                           onTap: () {
//                             String contactPersonName = _contactPersonNameController.text.trim();
//                             String phone = (_countryDialCode ?? '') + _contactPersonNumberController.text.trim();
//                             String email = _contactPersonEmailController.text.trim();
//                             String city = _cityController.text.trim();
//                             String zip = _zipCodeController.text.trim();
//                             String addressType = widget.isBilling! ? 'billing':'shipping';
//                             String address =  locationProvider.locationTextEditingController.text.trim();
//                             orderProvider.editShippingAndBillingAddress(orderID: widget.orderId, addressType: addressType, contactPersonName: contactPersonName,
//                             phone: phone, city: city, zip: zip, address:address, email: email, latitude: widget.lat, longitude: widget.lng);
//                           },
//                         )
//                       )
//                     ],
//                   ),
//                 );
//               }
//             );
//           }
//         ),
//       ),
//     );
//   }
//
// }
//
// enum Address {shipping, billing }