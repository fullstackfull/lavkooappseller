import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/custom_app_bar_widget.dart';
import 'package:syriacosmeticsmanger/features/security/controllers/security_controller.dart';
import 'package:syriacosmeticsmanger/features/security/widgets/security_widgets.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// Who can act as this shop, and what they have done with it.
///
/// Four tabs rather than four screens, because they are one question seen from
/// four sides: the people, the authorities those people hold, the keys standing
/// in for systems rather than people, and the record of what all of them did.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Provider.of<SecurityController>(context, listen: false).load(),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: getTranslated('security_centre', context)),
      body: Consumer<SecurityController>(
        builder: (context, security, _) {
          if (security.isLoading && security.access.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
            );
          }

          // Shown the moment a credential is created and never again, because
          // there is no endpoint that returns it a second time.
          final String? credential = security.freshKey ?? security.freshSecret;

          return Column(children: [
            if (credential != null)
              FreshCredentialBanner(
                credential: credential,
                isKey: security.freshKey != null,
                onCopy: () => Clipboard.setData(ClipboardData(text: credential)),
                onDismiss: security.clearFreshCredentials,
              ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall),
              unselectedLabelStyle: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
              tabs: [
                Tab(text: getTranslated('people', context)),
                Tab(text: getTranslated('roles', context)),
                Tab(text: getTranslated('keys_and_webhooks', context)),
                Tab(text: getTranslated('activity_log', context)),
              ],
            ),
            Expanded(
              child: TabBarView(controller: _tabs, children: [
                _PeopleTab(security: security),
                _RolesTab(security: security),
                _IntegrationsTab(security: security),
                _AuditTab(security: security),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _PeopleTab extends StatelessWidget {
  final SecurityController security;
  const _PeopleTab({required this.security});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: security.load,
      color: Theme.of(context).cardColor,
      backgroundColor: Theme.of(context).primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        children: [
          SectionHeader(
            title: getTranslated('who_can_act_as_this_shop', context),
            subtitle: getTranslated('signed_in_means_a_live_session_right_now', context),
            action: getTranslated('add_person', context),
            onAction: () => showStaffSheet(context, security),
          ),
          ...security.access.map((holder) => AccessHolderTile(holder: holder)),
          if (security.staff.isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeDefault),
            SectionHeader(title: getTranslated('staff', context)),
            ...security.staff.map((member) => StaffTile(
                  member: member,
                  onEdit: () => showStaffSheet(context, security, member: member),
                  onSignOut: member.signedIn ? () => security.signOutStaff(member.id) : null,
                  onDelete: () => confirmThen(
                    context,
                    getTranslated('remove_this_person_from_the_shop', context),
                    () => security.deleteStaff(member.id),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _RolesTab extends StatelessWidget {
  final SecurityController security;
  const _RolesTab({required this.security});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: security.load,
      color: Theme.of(context).cardColor,
      backgroundColor: Theme.of(context).primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        children: [
          SectionHeader(
            title: getTranslated('roles', context),
            subtitle: getTranslated('a_change_here_takes_effect_on_the_next_request', context),
            action: getTranslated('add_role', context),
            onAction: () => showRoleSheet(context, security),
          ),
          if (security.roles.isEmpty)
            EmptyNote(text: getTranslated('no_roles_yet', context)),
          ...security.roles.map((role) => RoleTile(
                role: role,
                onEdit: () => showRoleSheet(context, security, role: role),
                onDelete: () => confirmThen(
                  context,
                  getTranslated('anybody_holding_this_role_keeps_their_account_and_loses_its_rights', context),
                  () => security.deleteRole(role.id),
                ),
              )),
        ],
      ),
    );
  }
}

class _IntegrationsTab extends StatelessWidget {
  final SecurityController security;
  const _IntegrationsTab({required this.security});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: security.load,
      color: Theme.of(context).cardColor,
      backgroundColor: Theme.of(context).primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        children: [
          SectionHeader(
            title: getTranslated('api_keys', context),
            subtitle: getTranslated('a_key_is_shown_once_and_can_never_be_read_again', context),
            action: getTranslated('issue_key', context),
            onAction: () => showKeySheet(context, security),
          ),
          if (security.keys.isEmpty) EmptyNote(text: getTranslated('no_keys_yet', context)),
          ...security.keys.map((key) => ApiKeyTile(
                apiKey: key,
                onRevoke: key.usable
                    ? () => confirmThen(
                          context,
                          getTranslated('anything_using_this_key_stops_working_immediately', context),
                          () => security.revokeKey(key.id),
                        )
                    : null,
              )),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          SectionHeader(
            title: getTranslated('webhooks', context),
            subtitle: getTranslated('we_call_these_when_something_happens_in_your_shop', context),
            action: getTranslated('add_endpoint', context),
            onAction: () => showWebhookSheet(context, security),
          ),
          if (security.webhooks.isEmpty) EmptyNote(text: getTranslated('no_endpoints_yet', context)),
          ...security.webhooks.map((webhook) => WebhookTile(
                webhook: webhook,
                onEdit: () => showWebhookSheet(context, security, webhook: webhook),
                onTest: () => security.testWebhook(webhook.id, webhook.events.isEmpty ? '' : webhook.events.first),
                onToggle: () => security.setWebhookStatus(webhook.id, webhook.isActive ? 'paused' : 'active'),
                onDelete: () => confirmThen(
                  context,
                  getTranslated('the_record_of_what_was_sent_stays', context),
                  () => security.deleteWebhook(webhook.id),
                ),
                onDeliveries: () => security.showDeliveriesFor(webhook.id),
              )),
          if (security.deliveries.isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeDefault),
            SectionHeader(
              title: getTranslated('recent_deliveries', context),
              action: getTranslated('show_all', context),
              onAction: () => security.showDeliveriesFor(null),
            ),
            ...security.deliveries.map((delivery) => DeliveryTile(delivery: delivery)),
          ],
        ],
      ),
    );
  }
}

class _AuditTab extends StatelessWidget {
  final SecurityController security;
  const _AuditTab({required this.security});

  /// The filters worth offering, which are the things a seller comes here
  /// asking about: who changed the team, what the rules did, where the money
  /// went.
  static const Map<String, String> _filters = {
    'all': '',
    'team': 'seller.staff',
    'rules': 'seller.automation',
    'keys': 'seller.api_key',
  };

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
        child: Row(
          children: _filters.entries.map((entry) {
            final bool selected = (security.auditFilter ?? '') == entry.value;

            return Padding(
              padding: const EdgeInsets.only(right: Dimensions.paddingSizeExtraSmall),
              child: ChoiceChip(
                label: Text(getTranslated('audit_filter_${entry.key}', context) ?? entry.key),
                selected: selected,
                onSelected: (_) => security.filterAudit(entry.value.isEmpty ? null : entry.value),
              ),
            );
          }).toList(),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: security.load,
          color: Theme.of(context).cardColor,
          backgroundColor: Theme.of(context).primaryColor,
          child: security.audit.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    EmptyNote(text: getTranslated('nothing_recorded_yet', context)),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  itemCount: security.audit.length,
                  itemBuilder: (context, index) => AuditTile(entry: security.audit[index]),
                ),
        ),
      ),
    ]);
  }
}
