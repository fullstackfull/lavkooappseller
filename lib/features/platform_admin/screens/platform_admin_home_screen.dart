import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_confirmation_dialog_widget.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_capability_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_alerts_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_audit_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_health_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_overview_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_sessions_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_sign_out.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_state_widgets.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/widgets/platform_admin_texts.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

enum _Tab {
  overview(Icons.dashboard_outlined, PlatformCapability.overview),
  alerts(Icons.notifications_none_rounded, PlatformCapability.alerts),
  health(Icons.monitor_heart_outlined, PlatformCapability.health),
  sessions(Icons.devices_other_outlined, PlatformCapability.sessions),
  auditLog(Icons.history_rounded, PlatformCapability.audit);

  const _Tab(this.icon, this.capability);

  final IconData icon;

  /// The part of the API the tab is made of: without it in the grant, the tab is not offered.
  final PlatformCapability capability;

  String title(BuildContext context) => switch (this) {
        _Tab.overview => getTranslated('overview', context)!,
        _Tab.alerts => getTranslated('platform_admin_alerts', context)!,
        _Tab.health => getTranslated('platform_admin_health', context)!,
        _Tab.sessions => getTranslated('sessions', context)!,
        _Tab.auditLog => getTranslated('platform_admin_audit_log', context)!,
      };
}

/// The platform admin's own home: the screens of the shell, one tab each, and only the ones the grant includes.
///
/// A tab is built, and asks for its figures, the first time it is opened; the
/// ones that were not opened cost nothing. When the app comes back after a long
/// time away, what had been held has been thrown away, and the tab in front asks
/// again; so it does when what the grant includes changed. A part of the API
/// the server stops including takes its tab with it, and the admin lands on the
/// first one that is left. An alert opens the overview of its market, and the alert
/// counts of a market card open the alerts of that market.
///
/// Below the bar: when the grant ends, if it does, and the warning that few recovery
/// codes are left, if they are. Signing out is on the sessions tab; a grant without
/// it gets a way out in the bar, because the server never withholds one.
class PlatformAdminHomeScreen extends StatefulWidget {
  const PlatformAdminHomeScreen({super.key});

  @override
  State<PlatformAdminHomeScreen> createState() => _PlatformAdminHomeScreenState();
}

class _PlatformAdminHomeScreenState extends State<PlatformAdminHomeScreen> with WidgetsBindingObserver {
  late final PlatformAdminController _controller;
  late int _seenAccessEpoch;
  _Tab? _current;
  final Set<_Tab> _opened = <_Tab>{};

  /// The tabs the grant includes, in their order.
  List<_Tab> get _tabs => <_Tab>[
        for (final _Tab tab in _Tab.values)
          if (_controller.can(tab.capability)) tab,
      ];

  @override
  void initState() {
    super.initState();
    _controller = Provider.of<PlatformAdminController>(context, listen: false);
    WidgetsBinding.instance.addObserver(this);
    _seenAccessEpoch = _controller.accessEpoch;
    _current = _tabs.firstOrNull;
    if (_current != null) _opened.add(_current!);
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrent());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      _controller.onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _resumed();
    }
  }

  Future<void> _resumed() async {
    final bool thrownAway = await _controller.onAppResumed();
    if (thrownAway && mounted) _loadCurrent();
  }

  /// The grant changed under the admin: the tab they were on may be gone, and what the tab in front held may have been thrown away.
  void _onControllerChanged() {
    final bool accessChanged = _controller.accessEpoch != _seenAccessEpoch;
    _seenAccessEpoch = _controller.accessEpoch;

    final List<_Tab> tabs = _tabs;
    final _Tab? previous = _current;
    final _Tab? kept = tabs.contains(previous) ? previous : tabs.firstOrNull;

    if (kept != previous) {
      setState(() {
        _current = kept;
        if (kept != null) _opened.add(kept);
      });
    }
    if (kept != null && (accessChanged || kept != previous)) _load(kept);
  }

  void _loadCurrent() {
    final _Tab? current = _current;
    if (current != null) _load(current);
  }

  void _load(_Tab tab) {
    switch (tab) {
      case _Tab.overview:
        _controller.loadOverview();
      case _Tab.alerts:
        _controller.loadAlerts();
      case _Tab.health:
        _controller.loadHealth();
      case _Tab.sessions:
        _controller.loadSessions();
      case _Tab.auditLog:
        _controller.loadAuditLog();
    }
  }

  void _open(_Tab tab) {
    setState(() {
      _current = tab;
      _opened.add(tab);
    });
    _load(tab);
  }

  void _openOverviewOf(String market) {
    _controller.selectMarket(market);
    _open(_Tab.overview);
  }

  /// Every alert of the market is shown, whatever severity was being looked at: the
  /// card said how many there are, and the list must be able to show that many.
  void _openAlertsOf(String market) {
    _controller.selectMarket(market);
    _controller.selectAlertSeverity(null);
    _open(_Tab.alerts);
  }

  Widget _screenOf(_Tab tab) => switch (tab) {
        _Tab.overview => PlatformAdminOverviewScreen(onOpenAlerts: _openAlertsOf),
        _Tab.alerts => PlatformAdminAlertsScreen(onOpenMarket: _openOverviewOf),
        _Tab.health => const PlatformAdminHealthScreen(),
        _Tab.sessions => const PlatformAdminSessionsScreen(),
        _Tab.auditLog => const PlatformAdminAuditScreen(),
      };

  Future<void> _confirmSignOut() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => CustomConfirmationDialogWidget(
        title: getTranslated('logout', dialogContext)!,
        description: getTranslated('platform_admin_sign_out_question', dialogContext)!,
        yesButtonText: getTranslated('confirm', dialogContext)!,
        noButtonText: getTranslated('cancel', dialogContext)!,
        onYesPressed: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (confirmed != true || !mounted) return;

    await signOutOfPlatformAdmin(context, _controller);
  }

  @override
  Widget build(BuildContext context) {
    final PlatformAdminController controller = context.watch<PlatformAdminController>();
    final List<_Tab> tabs = _tabs;
    final _Tab? current = tabs.contains(_current) ? _current : tabs.firstOrNull;
    final DateTime? grantEnd = controller.profile?.grantExpiresAt;
    final int? recoveryCodesLeft = controller.recoveryCodesWarning;

    return Scaffold(
      appBar: CustomAppBarWidget(
        title: current?.title(context) ?? getTranslated('platform_admin_title', context),
        isAction: !tabs.contains(_Tab.sessions),
        isTooltip: true,
        widget: tabs.contains(_Tab.sessions)
            ? null
            : IconButton(
                tooltip: getTranslated('logout', context),
                onPressed: _confirmSignOut,
                icon: Icon(Icons.logout_rounded,
                    size: Dimensions.iconSizeMedium, color: Theme.of(context).colorScheme.error),
              ),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Column(children: [
          // What is said above the screens may take no more than two fifths of the room, and scrolls when it would: a large text must not push the screen off the phone.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.4),
            child: SingleChildScrollView(
              child: Column(children: [
                if (grantEnd != null) _AccessEnds(end: grantEnd),
                if (recoveryCodesLeft != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, 0),
                    child: PlatformAdminNote(
                      text: PlatformAdminTexts.recoveryCodesLow(context, recoveryCodesLeft),
                      icon: Icons.key_outlined,
                      onDismiss: controller.dismissRecoveryWarning,
                    ),
                  ),
              ]),
            ),
          ),
          Expanded(
            child: current == null
                ? const _NoAccess()
                : IndexedStack(
                    index: tabs.indexOf(current),
                    children: [
                      for (final _Tab tab in tabs) _opened.contains(tab) ? _screenOf(tab) : const SizedBox.shrink()
                    ],
                  ),
          ),
        ]),
      ),
      // A bar with fewer than two places to go has nothing to choose between.
      bottomNavigationBar: tabs.length < 2
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: tabs.indexOf(current!),
              onTap: (int index) => _open(tabs[index]),
              backgroundColor: Theme.of(context).cardColor,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Theme.of(context).hintColor,
              selectedFontSize: Dimensions.fontSizeSmall,
              unselectedFontSize: Dimensions.fontSizeSmall,
              items: [
                for (final _Tab tab in tabs) BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.title(context)),
              ],
            ),
    );
  }
}

/// When the grant ends. A line under the bar, in the quiet colour, and there only for a grant that has an end.
class _AccessEnds extends StatelessWidget {
  final DateTime end;

  const _AccessEnds({required this.end});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeExtraSmall),
      child: Row(children: [
        Icon(Icons.event_available_outlined, size: Dimensions.iconSizeSmall, color: Theme.of(context).hintColor),
        const SizedBox(width: Dimensions.paddingSizeExtraSmall),
        Expanded(
          child: Text(
            '${getTranslated('platform_admin_access_ends', context)!}: ${PlatformAdminTexts.moment(end)}',
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
          ),
        ),
      ]),
    );
  }
}

/// A grant that includes no part of the API at all: there is nothing to show, and the way out is in the bar.
class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 44, color: Theme.of(context).hintColor),
          const SizedBox(height: Dimensions.paddingSize),
          Text(
            getTranslated('platform_admin_no_access', context)!,
            textAlign: TextAlign.center,
            style: robotoRegular.copyWith(color: Theme.of(context).hintColor),
          ),
        ]),
      ),
    );
  }
}
