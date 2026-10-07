import 'package:flutter/material.dart';

import '../auth/agent_email.dart';
import '../auth/login_id.dart';
import '../core/di/injection.dart';
import '../core/navigation/app_page_route.dart';
import '../core/navigation/auth_reveal.dart';
import '../l10n/strings.dart';
import '../presentation/agent/agent_home_page.dart';
import 'change_password_screen.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import 'agent_forgot_password_screen.dart';

class AgentLoginScreen extends StatefulWidget {
  const AgentLoginScreen({super.key});

  @override
  State<AgentLoginScreen> createState() => _AgentLoginScreenState();
}

class _AgentLoginScreenState extends State<AgentLoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final s = S(AppScope.of(context).language);
    final address = AgentEmail.normalize(email.text);
    if (address.isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.fillAll)),
      );
      return;
    }

    setState(() => busy = true);
    ScaffoldMessenger.of(context).clearSnackBars();
    try {
      final data = await Injection.agentLogin(
        email: address,
        password: password.text,
      );
      if (!mounted) return;
      final app = AppScope.of(context);
      app.applyRemoteLogin(data, notify: false, scheduleLedger: false);
      if (app.currentRole != UserRole.agent) {
        app.finishLoginReveal();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.incorrectCredentials)),
        );
        if (mounted) setState(() => busy = false);
        return;
      }
      if (!mounted) return;
      await playAuthReveal(
        context: context,
        outgoing: _face(interactive: false),
        incoming: app.mustChangePassword
            ? const ChangePasswordScreen(forced: true)
            : const AgentHomePage(),
        onSettled: app.finishLoginReveal,
      );
    } catch (e) {
      if (!mounted) return;
      final status = e is ApiException ? e.statusCode : null;
      final raw = e.toString().replaceFirst('Exception: ', '');
      final message = status == 401
          ? s.incorrectCredentials
          : (status == 429
              ? s.tooManyRequests
              : (raw.contains('did not respond') ||
                      raw.contains('TimeoutException')
                  ? s.connectionTimeout
                  : raw));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _face({required bool interactive}) {
    final s = S(AppScope.of(context).language);
    return Scaffold(
      resizeToAvoidBottomInset: interactive,
      appBar: AppBar(title: Text(s.agentLoginTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            s.agentLoginHint,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: email,
            autofocus: interactive && !busy,
            enabled: interactive,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: s.email,
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: password,
            enabled: interactive,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: s.agentPassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: interactive
                  ? IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => obscure = !obscure),
                    )
                  : Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (interactive)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          AppPageRoute(
                            builder: (_) => AgentForgotPasswordScreen(
                              email: email.text,
                            ),
                          ),
                        );
                      },
                child: Text(
                  s.forgotPassword,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
          else
            const SizedBox(height: 12),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: interactive && !busy ? login : null,
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      s.loginAsAgent,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _face(interactive: true);
}
