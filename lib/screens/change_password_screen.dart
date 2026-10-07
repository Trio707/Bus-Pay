import 'package:flutter/material.dart';

import '../auth/agent_password_rule.dart';
import '../l10n/strings.dart';
import '../presentation/agent/agent_home_page.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});

  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final current = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool obscureCurrent = true;
  bool obscure = true;
  bool obscureConfirm = true;
  bool busy = false;

  @override
  void dispose() {
    current.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final s = S(AppScope.of(context).language);
    if (current.text.isEmpty ||
        password.text.isEmpty ||
        confirm.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.fillAll)),
      );
      return;
    }
    if (!AgentPasswordRule.isValid(password.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.passwordTooWeak)),
      );
      return;
    }
    if (password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.passwordMismatch)),
      );
      return;
    }

    final app = AppScope.of(context);
    final token = app.authToken ?? '';
    setState(() => busy = true);
    try {
      await ApiService.changeAgentPassword(
        token: token,
        currentPassword: current.text,
        password: password.text,
        confirmPassword: confirm.text,
      );
      if (!mounted) return;
      app.passwordChangeCompleted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.passwordChanged)),
      );
      if (widget.forced) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AgentHomePage()),
          (route) => false,
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(AppScope.of(context).language);
    final level = AgentPasswordRule.strength(password.text);
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.forced,
        title: Text(s.changePassword),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            s.changePasswordHint,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: current,
            obscureText: obscureCurrent,
            decoration: InputDecoration(
              labelText: s.currentPassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureCurrent ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => obscureCurrent = !obscureCurrent);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: password,
            obscureText: obscure,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: s.newPassword,
              helperText: password.text.isEmpty
                  ? s.strongPasswordHint
                  : s.passwordStrength(level),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => obscure = !obscure),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: confirm,
            obscureText: obscureConfirm,
            decoration: InputDecoration(
              labelText: s.confirmPassword,
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureConfirm ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => obscureConfirm = !obscureConfirm);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: busy ? null : submit,
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      s.changePassword,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
