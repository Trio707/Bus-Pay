import 'package:flutter/material.dart';

import '../auth/nida_id.dart';
import '../auth/password_rule.dart';
import '../auth/tz_phone.dart';
import '../core/navigation/app_page_route.dart';
import '../l10n/strings.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../widgets/pin_boxes.dart';
import 'fingerprint_scan_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int step = 0;
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final nida = TextEditingController();
  String pin = '';
  String confirmPin = '';
  bool busy = false;
  String phoneError = '';
  String nidaError = '';
  int _checkGen = 0;

  @override
  void initState() {
    super.initState();
    phone.value = TextEditingValue(
      text: TzPhone.format(''),
      selection: TextSelection.collapsed(offset: TzPhone.format('').length),
    );
    phone.addListener(_onIdentityChanged);
    nida.addListener(_onIdentityChanged);
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    nida.dispose();
    super.dispose();
  }

  void _onIdentityChanged() {
    final gen = ++_checkGen;
    Future<void>.delayed(const Duration(milliseconds: 250), () async {
      if (!mounted || gen != _checkGen) return;
      final s = S(AppScope.of(context).language);
      var nextPhone = '';
      var nextNida = '';
      try {
        if (TzPhone.isValid(phone.text) || NidaId.isValid(nida.text)) {
          final data = await ApiService.checkAvailability(
            phone: TzPhone.isValid(phone.text) ? TzPhone.toApi(phone.text) : null,
            nida: NidaId.isValid(nida.text) ? NidaId.toApi(nida.text) : null,
          );
          if (!mounted || gen != _checkGen) return;
          if (data['phoneTaken'] == true) nextPhone = s.phoneAlreadyUsed;
          if (data['nidaTaken'] == true) nextNida = s.nidaAlreadyUsed;
        }
      } catch (_) {}
      if (!mounted || gen != _checkGen) return;
      setState(() {
        phoneError = nextPhone;
        nidaError = nextNida;
      });
    });
  }

  Future<void> goToFingerprint() async {
    final s = S(AppScope.of(context).language);
    if (firstName.text.isEmpty ||
        lastName.text.isEmpty ||
        !TzPhone.isValid(phone.text) ||
        !NidaId.isValid(nida.text) ||
        phoneError.isNotEmpty ||
        nidaError.isNotEmpty) {
      setState(() {
        if (!TzPhone.isValid(phone.text)) phoneError = s.badPhoneFormat;
        if (!NidaId.isValid(nida.text)) nidaError = s.badNidaFormat;
      });
      if (firstName.text.isEmpty || lastName.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.fillAll)),
        );
      }
      return;
    }

    final ok = await Navigator.push<bool>(
      context,
      AppPageRoute(builder: (_) => const FingerprintScanScreen()),
    );
    if (!mounted || ok != true) return;
    setState(() => step = 1);
  }

  Future<void> finish() async {
    final s = S(AppScope.of(context).language);
    if (!PasswordRule.isValid(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.badPinFormat)),
      );
      return;
    }
    if (pin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.pinMismatch)),
      );
      return;
    }

    setState(() => busy = true);
    try {
      final data = await ApiService.register(
        firstName: firstName.text,
        lastName: lastName.text,
        phone: TzPhone.toApi(phone.text),
        nida: NidaId.toApi(nida.text),
        pin: pin,
        confirmPin: confirmPin,
      );
      if (!mounted) return;

      final username = data['username']?.toString() ?? '';
      if (username.isNotEmpty) {
        await AppScope.of(context).rememberAccount(username);
      }
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text(s.confirm),
            content: Text(s.registrationOk),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(s.confirm),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst('Exception: ', '');
      final lower = raw.toLowerCase();
      setState(() {
        if (lower.contains('phone already')) {
          phoneError = s.phoneAlreadyUsed;
          step = 0;
        } else if (lower.contains('nida already')) {
          nidaError = s.nidaAlreadyUsed;
          step = 0;
        }
      });
      if (phoneError.isEmpty && nidaError.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              raw.contains('did not respond') ||
                      raw.contains('TimeoutException') ||
                      raw.contains('Could not reach')
                  ? s.connectionTimeout
                  : raw,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(AppScope.of(context).language);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.signUp),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: busy
              ? null
              : () {
                  if (step == 1) {
                    setState(() => step = 0);
                    return;
                  }
                  Navigator.pop(context);
                },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (step == 0) ..._details(s) else ..._pins(s),
        ],
      ),
    );
  }

  List<Widget> _details(S s) {
    return [
      TextField(
        controller: firstName,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: s.firstName,
          prefixIcon: const Icon(Icons.person_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: lastName,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: s.lastName,
          prefixIcon: const Icon(Icons.person_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        inputFormatters: const [TzPhoneFormatter()],
        decoration: InputDecoration(
          labelText: s.phone,
          prefixIcon: const Icon(Icons.phone_outlined),
          errorText: phoneError.isEmpty ? null : phoneError,
          errorStyle: const TextStyle(fontSize: 12, color: Colors.red),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: nida,
        keyboardType: TextInputType.number,
        inputFormatters: const [NidaFormatter()],
        decoration: InputDecoration(
          labelText: s.nida,
          prefixIcon: const Icon(Icons.badge_outlined),
          errorText: nidaError.isEmpty ? null : nidaError,
          errorStyle: const TextStyle(fontSize: 12, color: Colors.red),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: goToFingerprint,
          child: Text(
            s.continueBtn,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    ];
  }

  List<Widget> _pins(S s) {
    return [
      Text(
        s.createPin,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(s.pinHint, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 20),
      PinBoxes(
        value: pin,
        label: s.wekaPin,
        autofocus: true,
        onChanged: (value) => setState(() => pin = value),
      ),
      const SizedBox(height: 24),
      PinBoxes(
        value: confirmPin,
        label: s.hakikiPin,
        onChanged: (value) => setState(() => confirmPin = value),
      ),
      const SizedBox(height: 28),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: busy ? null : finish,
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  s.signUp,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
        ),
      ),
    ];
  }
}
