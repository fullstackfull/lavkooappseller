import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/notification/controllers/notification_controller.dart';
import 'package:syriacosmeticsmanger/features/notification/screens/notification_screen.dart';
import 'package:syriacosmeticsmanger/features/storefront/storefront_config.dart';
import 'package:syriacosmeticsmanger/features/storefront/widgets/market_labeled_action.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/images.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The title area of the dashboard: the logo, and the bell of the notifications with the market in front of it while storefronts are on.
class HomeAppBarWidget extends StatelessWidget {
  const HomeAppBarWidget({super.key, this.storefrontsEnabled = StorefrontConfig.enabled});

  /// Whether the market label is part of the title area: only in a build with storefronts on.
  final bool storefrontsEnabled;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      surfaceTintColor: Theme.of(context).highlightColor,
      backgroundColor: Theme.of(context).highlightColor,
      snap: true,
      title: Image.asset(Images.logoWithAppName, height: 35),
      actions: [
        MarketLabeledAction(
          enabled: storefrontsEnabled,
          action: Consumer<NotificationController>(
            builder: (context, notificationController, _) {
              return InkWell(onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const NotificationScreen())),
                child: Stack(
                  children: [
                    Padding(padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, 0),
                      child: Icon(CupertinoIcons.bell, color: Theme.of(context).primaryColor),
                    ),
                    Positioned(top: 5,right: 18,child: Align(alignment: AlignmentDirectional.topEnd,
                      child: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.error,
                        radius: 8,child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Text('${notificationController.notificationModel?.newNotificationItem??0}',
                              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white),),
                          ),
                        ),)
                      )
                    ),
                  ],
                ),
              );
            }
          ),
        ),
      ],
    );
  }
}
