import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../presentation/auth/register/patient/utils/phone_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/patient_tokens.dart';
import 'patient_ui.dart';

/// Changing the phone number or PIN of a phone + PIN account. Both go
/// through the `patient-auth` Edge Function (see AuthProvider.changePhone):
/// the sign-in password is built from phone + PIN, so neither can change
/// on its own without locking the patient out.

/// Returns true when the phone number was changed.
Future<bool> showChangePhoneDialog(BuildContext context) async {
  final changed = await showPModal<bool>(
    context: context,
    title: 'Change phone number',
    builder: (_) => const _ChangePhoneForm(),
  );
  return changed ?? false;
}

/// Returns true when the PIN was changed.
Future<bool> showChangePinDialog(BuildContext context) async {
  final changed = await showPModal<bool>(
    context: context,
    title: 'Change PIN',
    builder: (_) => const _ChangePinForm(),
  );
  return changed ?? false;
}

class _ChangePhoneForm extends StatefulWidget {
  const _ChangePhoneForm();

  @override
  State<_ChangePhoneForm> createState() => _ChangePhoneFormState();
}

class _ChangePhoneFormState extends State<_ChangePhoneForm> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formatted = PhoneFormatter.format(_phone.text);
    if (formatted == null) {
      setState(() => _error = 'Enter a valid Kenyan phone number, like 0712 345 678.');
      return;
    }
    if (_pin.text.length != 6) {
      setState(() => _error = 'Enter your 6-digit PIN.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.changePhone(newPhone: formatted, pin: _pin.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = auth.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'You log in with your phone number and PIN, so from now on you will '
          'log in with the new number. Your PIN stays the same.',
          style: PT.sub(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'New phone number', hintText: '0712 345 678'),
        ),
        const SizedBox(height: 12),
        _PinField(controller: _pin, label: 'Your PIN', enabled: !_busy),
        if (_error != null) ...[
          const SizedBox(height: 12),
          PCallout(body: _error!, tone: PTone.red),
        ],
        const SizedBox(height: 20),
        _Actions(busy: _busy, confirmLabel: 'Change number', onConfirm: _submit),
      ],
    );
  }
}

class _ChangePinForm extends StatefulWidget {
  const _ChangePinForm();

  @override
  State<_ChangePinForm> createState() => _ChangePinFormState();
}

class _ChangePinFormState extends State<_ChangePinForm> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    String? problem;
    if (_current.text.length != 6) {
      problem = 'Enter your current 6-digit PIN.';
    } else if (_new.text.length != 6) {
      problem = 'Your new PIN must be 6 digits.';
    } else if (_new.text != _confirm.text) {
      problem = 'The two new PINs are not the same.';
    } else if (_new.text == _current.text) {
      problem = 'Your new PIN is the same as your current one.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.changePin(currentPin: _current.text, newPin: _new.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = auth.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Next time you log in, use your new PIN.', style: PT.sub()),
        const SizedBox(height: 16),
        _PinField(controller: _current, label: 'Current PIN', enabled: !_busy),
        const SizedBox(height: 12),
        _PinField(controller: _new, label: 'New PIN', enabled: !_busy),
        const SizedBox(height: 12),
        _PinField(controller: _confirm, label: 'New PIN again', enabled: !_busy),
        if (_error != null) ...[
          const SizedBox(height: 12),
          PCallout(body: _error!, tone: PTone.red),
        ],
        const SizedBox(height: 20),
        _Actions(busy: _busy, confirmLabel: 'Change PIN', onConfirm: _submit),
      ],
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({required this.controller, required this.label, required this.enabled});

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, counterText: ''),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.busy, required this.confirmLabel, required this.onConfirm});

  final bool busy;
  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PButton(
            'Cancel',
            kind: PButtonKind.alt,
            expand: true,
            onPressed: busy ? null : () => Navigator.pop(context, false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PButton(
            busy ? 'Please wait…' : confirmLabel,
            expand: true,
            onPressed: busy ? null : onConfirm,
          ),
        ),
      ],
    );
  }
}
