import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/features/security/controllers/security_controller.dart';
import 'package:syriacosmeticsmanger/features/security/domain/models/security_models.dart';
import 'package:syriacosmeticsmanger/localization/language_constrants.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';
import 'package:syriacosmeticsmanger/utill/styles.dart';

/// The one moment a credential exists.
///
/// Loud on purpose. A seller who closes this without copying has to issue a new
/// key, and telling them that afterwards would be too late.
class FreshCredentialBanner extends StatelessWidget {
  final String credential;
  final bool isKey;
  final VoidCallback onCopy;
  final VoidCallback onDismiss;

  const FreshCredentialBanner({
    super.key,
    required this.credential,
    required this.isKey,
    required this.onCopy,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          getTranslated(isKey ? 'copy_this_key_now' : 'copy_this_secret_now', context) ?? '',
          style: robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall),
        ),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(
          getTranslated('it_is_not_shown_again', context) ?? '',
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        SelectableText(credential, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Row(children: [
          TextButton(onPressed: onCopy, child: Text(getTranslated('copy', context) ?? '')),
          const Spacer(),
          TextButton(onPressed: onDismiss, child: Text(getTranslated('i_have_saved_it', context) ?? '')),
        ]),
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, this.title, this.subtitle, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeExtraSmall,
        vertical: Dimensions.paddingSizeSmall,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title ?? '', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeDefault)),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
          ]),
        ),
        if (action != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String? text;
  const EmptyNote({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
      child: Text(
        text ?? '',
        textAlign: TextAlign.center,
        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraSmall),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
        border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.15)),
      ),
      child: child,
    );
  }
}

class AccessHolderTile extends StatelessWidget {
  final AccessHolderModel holder;
  const AccessHolderTile({super.key, required this.holder});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(children: [
        Icon(
          holder.isOwner ? Icons.verified_user_outlined : Icons.person_outline,
          size: 20,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(holder.name ?? '', style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
            Text(
              holder.isOwner
                  ? (getTranslated('owner', context) ?? '')
                  : (holder.role ?? getTranslated('no_role', context) ?? ''),
              style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: Theme.of(context).hintColor,
              ),
            ),
          ]),
        ),
        _Pill(
          label: getTranslated(holder.signedIn ? 'signed_in' : 'not_signed_in', context) ?? '',
          tone: holder.signedIn ? _Tone.positive : _Tone.neutral,
        ),
      ]),
    );
  }
}

class StaffTile extends StatelessWidget {
  final SellerStaffModel member;
  final VoidCallback onEdit;
  final VoidCallback? onSignOut;
  final VoidCallback onDelete;

  const StaffTile({
    super.key,
    required this.member,
    required this.onEdit,
    required this.onDelete,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(member.name, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
              Text(
                member.email,
                style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ]),
          ),
          _Pill(
            label: member.role ?? getTranslated('no_role', context) ?? '',
            tone: member.role == null ? _Tone.warning : _Tone.neutral,
          ),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          _Pill(
            label: getTranslated(member.isActive ? 'active' : 'switched_off', context) ?? '',
            tone: member.isActive ? _Tone.positive : _Tone.negative,
          ),
        ]),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Row(children: [
          TextButton(onPressed: onEdit, child: Text(getTranslated('edit', context) ?? '')),
          if (onSignOut != null)
            TextButton(onPressed: onSignOut, child: Text(getTranslated('sign_out_everywhere', context) ?? '')),
          const Spacer(),
          TextButton(onPressed: onDelete, child: Text(getTranslated('remove', context) ?? '')),
        ]),
      ]),
    );
  }
}

class RoleTile extends StatelessWidget {
  final SellerRoleModel role;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RoleTile({super.key, required this.role, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(role.name, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall))),
          _Pill(
            label: '${role.staffCount} ${getTranslated('people', context) ?? ''}',
            tone: _Tone.neutral,
          ),
        ]),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(
          role.permissions.isEmpty
              ? (getTranslated('can_sign_in_and_do_nothing', context) ?? '')
              : role.permissions.join(' · '),
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: Theme.of(context).hintColor,
          ),
        ),
        Row(children: [
          TextButton(onPressed: onEdit, child: Text(getTranslated('edit', context) ?? '')),
          const Spacer(),
          TextButton(onPressed: onDelete, child: Text(getTranslated('delete', context) ?? '')),
        ]),
      ]),
    );
  }
}

class ApiKeyTile extends StatelessWidget {
  final ApiKeyModel apiKey;
  final VoidCallback? onRevoke;

  const ApiKeyTile({super.key, required this.apiKey, this.onRevoke});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(apiKey.name, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall))),
          _Pill(
            label: getTranslated(apiKey.usable ? 'active' : 'revoked', context) ?? '',
            tone: apiKey.usable ? _Tone.positive : _Tone.negative,
          ),
        ]),
        Text(
          'sk_seller_${apiKey.prefix}…',
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(
          apiKey.scopes.isEmpty
              ? (getTranslated('can_read_nothing', context) ?? '')
              : apiKey.scopes.join(' · '),
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
        ),
        Text(
          // "Never used" is a fact worth showing plainly: it is usually the
          // answer to "can I revoke this?".
          apiKey.neverUsed
              ? (getTranslated('never_used', context) ?? '')
              : '${getTranslated('last_used', context) ?? ''} ${apiKey.lastUsedAt}',
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: Theme.of(context).hintColor,
          ),
        ),
        if (onRevoke != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: onRevoke, child: Text(getTranslated('revoke', context) ?? '')),
          ),
      ]),
    );
  }
}

class WebhookTile extends StatelessWidget {
  final WebhookModel webhook;
  final VoidCallback onEdit;
  final VoidCallback onTest;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onDeliveries;

  const WebhookTile({
    super.key,
    required this.webhook,
    required this.onEdit,
    required this.onTest,
    required this.onToggle,
    required this.onDelete,
    required this.onDeliveries,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(webhook.name, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall))),
          _Pill(label: getTranslated(webhook.status, context) ?? webhook.status, tone: _toneFor(webhook)),
        ]),
        Text(
          webhook.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(webhook.events.join(' · '), style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
        Text(
          _health(context),
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: Theme.of(context).hintColor,
          ),
        ),
        Wrap(children: [
          TextButton(onPressed: onEdit, child: Text(getTranslated('edit', context) ?? '')),
          TextButton(onPressed: onTest, child: Text(getTranslated('send_test', context) ?? '')),
          TextButton(
            onPressed: onToggle,
            child: Text(getTranslated(webhook.isActive ? 'pause' : 'resume', context) ?? ''),
          ),
          TextButton(onPressed: onDeliveries, child: Text(getTranslated('deliveries', context) ?? '')),
          TextButton(onPressed: onDelete, child: Text(getTranslated('delete', context) ?? '')),
        ]),
      ]),
    );
  }

  /// An endpoint nothing has been sent to says so, rather than showing a green
  /// tick it has not earned.
  String _health(BuildContext context) {
    if (webhook.isDisabled) {
      return getTranslated(webhook.disabledReason ?? 'webhook_disabled', context) ?? '';
    }

    if (webhook.neverCalled) {
      return getTranslated('nothing_has_been_sent_to_this_yet', context) ?? '';
    }

    if (webhook.consecutiveFailures > 0) {
      return '${getTranslated('failing_since', context) ?? ''} ${webhook.lastFailureAt}'
          ' (${webhook.consecutiveFailures})';
    }

    return '${getTranslated('last_delivered', context) ?? ''} ${webhook.lastSuccessAt}';
  }

  _Tone _toneFor(WebhookModel webhook) {
    if (webhook.isDisabled) return _Tone.negative;
    if (!webhook.isActive) return _Tone.neutral;

    return webhook.consecutiveFailures > 0 ? _Tone.warning : _Tone.positive;
  }
}

class DeliveryTile extends StatelessWidget {
  final WebhookDeliveryModel delivery;
  const DeliveryTile({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(delivery.event, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall))),
          _Pill(
            label: delivery.responseCode?.toString() ?? (getTranslated('no_answer', context) ?? ''),
            tone: delivery.delivered ? _Tone.positive : _Tone.negative,
          ),
        ]),
        Text(
          '${delivery.createdAt} · ${getTranslated('attempts', context) ?? ''} ${delivery.attempts}',
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: Theme.of(context).hintColor,
          ),
        ),
        if (delivery.error != null && delivery.error!.isNotEmpty)
          Text(delivery.error!, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
        if (delivery.responseBody != null && delivery.responseBody!.isNotEmpty)
          Text(
            delivery.responseBody!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
          ),
        if (delivery.nextAttemptAt != null)
          Text(
            '${getTranslated('next_attempt', context) ?? ''} ${delivery.nextAttemptAt}',
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeExtraSmall,
              color: Theme.of(context).hintColor,
            ),
          ),
      ]),
    );
  }
}

class AuditTile extends StatelessWidget {
  final AuditEntryModel entry;
  const AuditTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          getTranslated(entry.action, context) ?? entry.action,
          style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
        ),
        Text(
          [entry.actorName, entry.createdAt].where((part) => part != null && part.isNotEmpty).join(' · '),
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeExtraSmall,
            color: Theme.of(context).hintColor,
          ),
        ),
      ]),
    );
  }
}

enum _Tone { positive, negative, warning, neutral }

class _Pill extends StatelessWidget {
  final String label;
  final _Tone tone;

  const _Pill({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      _Tone.positive => Colors.green,
      _Tone.negative => Theme.of(context).colorScheme.error,
      _Tone.warning => Colors.orange,
      _Tone.neutral => Theme.of(context).hintColor,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
    );
  }
}

Future<void> confirmThen(BuildContext context, String? message, Future<bool> Function() action) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message ?? '', style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(getTranslated('cancel', context) ?? ''),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(getTranslated('confirm', context) ?? ''),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await action();
  }
}

Future<void> showRoleSheet(BuildContext context, SecurityController security, {SellerRoleModel? role}) {
  final TextEditingController name = TextEditingController(text: role?.name ?? '');
  final Set<String> chosen = {...?role?.permissions};

  return _sheet(
    context,
    title: getTranslated(role == null ? 'add_role' : 'edit_role', context),
    builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(
        controller: name,
        decoration: InputDecoration(labelText: getTranslated('role_name', context)),
      ),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      // Grouped as the server groups them, so the form never falls behind the
      // permissions the platform actually has.
      ...security.permissionGroups.entries.map((group) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
                child: Text(
                  getTranslated(group.key, context) ?? group.key,
                  style: robotoBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
                ),
              ),
              Wrap(
                spacing: Dimensions.paddingSizeExtraSmall,
                children: group.value
                    .map((permission) => FilterChip(
                          label: Text(permission, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
                          selected: chosen.contains(permission),
                          onSelected: (on) => setState(() => on ? chosen.add(permission) : chosen.remove(permission)),
                        ))
                    .toList(),
              ),
            ],
          )),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      _SubmitButton(
        label: getTranslated('save', context),
        onPressed: () => security.saveRole(id: role?.id, name: name.text.trim(), permissions: chosen.toList()),
      ),
    ]),
  );
}

Future<void> showStaffSheet(BuildContext context, SecurityController security, {SellerStaffModel? member}) {
  final TextEditingController name = TextEditingController(text: member?.name ?? '');
  final TextEditingController email = TextEditingController(text: member?.email ?? '');
  final TextEditingController password = TextEditingController();
  int? roleId = member?.roleId;
  String status = member?.status ?? 'active';

  return _sheet(
    context,
    title: getTranslated(member == null ? 'add_person' : 'edit_person', context),
    builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: InputDecoration(labelText: getTranslated('name', context))),
      if (member == null)
        TextField(controller: email, decoration: InputDecoration(labelText: getTranslated('email', context))),
      TextField(
        controller: password,
        obscureText: true,
        decoration: InputDecoration(
          labelText: getTranslated(member == null ? 'password' : 'new_password_optional', context),
        ),
      ),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      DropdownButtonFormField<int?>(
        initialValue: roleId,
        decoration: InputDecoration(labelText: getTranslated('role', context)),
        items: [
          DropdownMenuItem<int?>(value: null, child: Text(getTranslated('no_role', context) ?? '')),
          ...security.roles.map((role) => DropdownMenuItem<int?>(value: role.id, child: Text(role.name))),
        ],
        onChanged: (value) => setState(() => roleId = value),
      ),
      if (member != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: status == 'active',
          title: Text(
            getTranslated('active', context) ?? '',
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
          ),
          subtitle: Text(
            getTranslated('switching_this_off_ends_their_session_now', context) ?? '',
            style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
          ),
          onChanged: (on) => setState(() => status = on ? 'active' : 'inactive'),
        ),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      _SubmitButton(
        label: getTranslated('save', context),
        onPressed: () => security.saveStaff(
          id: member?.id,
          name: name.text.trim(),
          email: email.text.trim(),
          password: password.text,
          roleId: roleId,
          status: status,
        ),
      ),
    ]),
  );
}

Future<void> showKeySheet(BuildContext context, SecurityController security) {
  final TextEditingController name = TextEditingController();
  final Set<String> chosen = <String>{};

  return _sheet(
    context,
    title: getTranslated('issue_key', context),
    builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(
        controller: name,
        decoration: InputDecoration(labelText: getTranslated('what_is_this_key_for', context)),
      ),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      Text(
        getTranslated('give_it_only_what_it_needs', context) ?? '',
        style: robotoRegular.copyWith(
          fontSize: Dimensions.fontSizeExtraSmall,
          color: Theme.of(context).hintColor,
        ),
      ),
      Wrap(
        spacing: Dimensions.paddingSizeExtraSmall,
        // Only what the person issuing it actually holds — the server narrows it
        // too, and offering more here would only produce a key that quietly
        // lacks half of what was ticked.
        children: security.grantableScopes
            .map((scope) => FilterChip(
                  label: Text(scope, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
                  selected: chosen.contains(scope),
                  onSelected: (on) => setState(() => on ? chosen.add(scope) : chosen.remove(scope)),
                ))
            .toList(),
      ),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      _SubmitButton(
        label: getTranslated('create', context),
        onPressed: () => security.issueKey(name: name.text.trim(), scopes: chosen.toList()),
      ),
    ]),
  );
}

Future<void> showWebhookSheet(BuildContext context, SecurityController security, {WebhookModel? webhook}) {
  final TextEditingController name = TextEditingController(text: webhook?.name ?? '');
  final TextEditingController url = TextEditingController(text: webhook?.url ?? '');
  final Set<String> chosen = {...?webhook?.events};

  return _sheet(
    context,
    title: getTranslated(webhook == null ? 'add_endpoint' : 'edit_endpoint', context),
    builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: InputDecoration(labelText: getTranslated('name', context))),
      TextField(
        controller: url,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(labelText: 'https://…'),
      ),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      Wrap(
        spacing: Dimensions.paddingSizeExtraSmall,
        children: security.events
            .map((event) => FilterChip(
                  label: Text(event, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
                  selected: chosen.contains(event),
                  onSelected: (on) => setState(() => on ? chosen.add(event) : chosen.remove(event)),
                ))
            .toList(),
      ),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      _SubmitButton(
        label: getTranslated('save', context),
        onPressed: () => security.saveWebhook(
          id: webhook?.id,
          name: name.text.trim(),
          url: url.text.trim(),
          events: chosen.toList(),
        ),
      ),
    ]),
  );
}

class _SubmitButton extends StatelessWidget {
  final String? label;
  final Future<bool> Function() onPressed;

  const _SubmitButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final SecurityController security = context.watch<SecurityController>();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: security.isSaving
            ? null
            : () async {
                final bool ok = await onPressed();

                if (ok && context.mounted) {
                  Navigator.pop(context);
                }
              },
        child: Text(security.isSaving ? (getTranslated('saving', context) ?? '') : (label ?? '')),
      ),
    );
  }
}

Future<void> _sheet(
  BuildContext context, {
  required String? title,
  required Widget Function(BuildContext, StateSetter) builder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: Dimensions.paddingSizeDefault,
        right: Dimensions.paddingSizeDefault,
        top: Dimensions.paddingSizeDefault,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + Dimensions.paddingSizeDefault,
      ),
      child: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (innerContext, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title ?? '', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            builder(innerContext, setState),
          ]),
        ),
      ),
    ),
  );
}
