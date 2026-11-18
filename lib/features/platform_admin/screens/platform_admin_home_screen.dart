import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/controllers/platform_admin_controller.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_alerts_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_audit_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_overview_screen.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/screens/platform_admin_sessions_screen.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';

enum _Tab {
  overview(Icons.dashboard_outlined),
  alerts(Icons.notifications_none_rounded),
  sessions(Icons.devices_other_outlined),
  auditLog(Icons.history_rounded);

  const _Tab(this.icon);

  final IconData icon;

  String title(BuildContext context) => switch (this) {
        _Tab.overview => getTranslated('overview', context)!,
        _Tab.alerts => getTranslated('platform_admin_alerts', context)!,
        _Tab.sessions => getTranslated('sessions', context)!,
        _Tab.auditLog => getTranslated('platform_admin_audit_log', context)!,
      };
}

/// The platform admin's own home: the screens of the shell, one tab each.
///
/// A tab is built, and asks for its figures, the first time it is opened; the
/// ones that were not opened cost nothing. When the app comes back after a long
/// time away, what had been held has been thrown away, and the tab in front asks
/// again. An alert opens the overview of its market, and the alert counts of a
/// market card open the alerts of that market.
class PlatformAdminHomeScreen extends StatefulWidget {
  const PlatformAdminHomeScreen({super.key});

  @override
  State<PlatformAdminHomeScreen> createState() => _PlatformAdminHomeScreenState();
}

class _PlatformAdminHomeScreenState extends State<PlatformAdminHomeScreen> with WidgetsBindingObserver {
  _Tab _current = _Tab.overview;
  final Set<_Tab> _opened = <_Tab>{_Tab.overview};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(_current));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final PlatformAdminController controller = Provider.of<PlatformAdminController>(context, listen: false);

    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      controller.onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _resumed(controller);
    }
  }

  Future<void> _resumed(PlatformAdminController controller) async {
    final bool thrownAway = await controller.onAppResumed();
    if (thrownAway && mounted) _load(_current);
  }

  void _load(_Tab tab) {
    final PlatformAdminController controller = Provider.of<PlatformAdminController>(context, listen: false);

    switch (tab) {
      case _Tab.overview:
        controller.loadOverview();
      case _Tab.alerts:
        controller.loadAlerts();
      case _Tab.sessions:
        controller.loadSessions();
      case _Tab.auditLog:
        controller.loadAuditLog();
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
    Provider.of<PlatformAdminController>(context, listen: false).selectMarket(market);
    _open(_Tab.overview);
  }

  /// Every alert of the market is shown, whatever severity was being looked at: the
  /// card said how many there are, and the list must be able to show that many.
  void _openAlertsOf(String market) {
    final PlatformAdminController controller = Provider.of<PlatformAdminController>(context, listen: false);
    controller.selectMarket(market);
    controller.selectAlertSeverity(null);
    _open(_Tab.alerts);
  }

  Widget _screenOf(_Tab tab) => switch (tab) {
        _Tab.overview => PlatformAdminOverviewScreen(onOpenAlerts: _openAlertsOf),
        _Tab.alerts => PlatformAdminAlertsScreen(onOpenMarket: _openOverviewOf),
        _Tab.sessions => const PlatformAdminSessionsScreen(),
        _Tab.auditLog => const PlatformAdminAuditScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: _current.title(context)),
      body: IndexedStack(
        index: _Tab.values.indexOf(_current),
        children: [
          for (final _Tab tab in _Tab.values) _opened.contains(tab) ? _screenOf(tab) : const SizedBox.shrink()
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _Tab.values.indexOf(_current),
        onTap: (int index) => _open(_Tab.values[index]),
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Theme.of(context).hintColor,
        selectedFontSize: Dimensions.fontSizeSmall,
        unselectedFontSize: Dimensions.fontSizeSmall,
        items: [
          for (final _Tab tab in _Tab.values) BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.title(context)),
        ],
      ),
    );
  }
}
