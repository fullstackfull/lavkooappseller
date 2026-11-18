import 'package:flutter/services.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_mfa_models.dart';

/// Keeps what is typed for an authenticator code to the digits of one.
///
/// The digits of an Arabic or a Persian keyboard are turned into 0 to 9, and anything that is not a digit, the
/// spaces and hyphens an app writes a code with included, is left out, so that a code can be pasted the way it is shown.
/// How many digits there may be is the limit of the field it is given to, which comes after it.
class PlatformCodeInputFormatter extends TextInputFormatter {
  const PlatformCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final String digits = PlatformSecondFactorInput.asciiDigits(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');

    return TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
  }
}

/// What a recovery code is typed with: letters, digits, spaces and the hyphen. The shape is checked when it is sent.
final TextInputFormatter platformRecoveryCodeInputFormatter =
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-]'));

/// The most a recovery code is typed with: `xxxxx-xxxxx`, and room for the spaces of a code that was written down in groups.
const int platformRecoveryCodeMaxLength = 14;
