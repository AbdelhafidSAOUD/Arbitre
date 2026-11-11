import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import 'brand.dart';
import 'common.dart';

/// Connexion sans mot de passe : un code à usage unique est envoyé par
/// e-mail. Aucun mot de passe à retenir ni à protéger.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool codeSent = false;
  bool passwordMode = false;
  bool busy = false;
  String? error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!_emailRe.hasMatch(email)) {
      setState(() => error = 'Adresse e-mail invalide. Vérifiez qu’elle contient un « @ » et un domaine.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppScope.read(context).sendCode(email);
      setState(() => codeSent = true);
    } on AuthException catch (e) {
      setState(() => error = e.statusCode == '429'
          ? 'Trop de demandes. Patientez une minute avant de redemander un code.'
          : 'Envoi impossible : ${e.message}');
    } catch (_) {
      setState(() => error = 'Envoi impossible. Vérifiez votre connexion Internet.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => error = 'Le code contient au moins 6 chiffres.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppScope.read(context).verifyCode(_email.text, code);
    } on AuthException {
      setState(() => error = 'Code incorrect ou expiré. Demandez un nouveau code.');
    } catch (_) {
      setState(() => error = 'Vérification impossible. Vérifiez votre connexion Internet.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _passwordLogin() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppScope.read(context).signInWithPassword(_email.text, _password.text);
    } on AuthException {
      setState(() => error = 'E-mail ou mot de passe incorrect.');
    } catch (_) {
      setState(() => error = 'Connexion impossible. Vérifiez votre connexion Internet.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              children: [
                const BrandMark(size: 44),
                const SizedBox(height: 28),
                Text('CONNEXION', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 6),
                Text(
                  codeSent
                      ? 'Nous avons envoyé un code à ${_email.text.trim()}. Il est valable une heure.'
                      : 'Aucun mot de passe : nous vous envoyons un code à usage unique par e-mail.',
                  style: TextStyle(color: c.muted),
                ),
                const SizedBox(height: 20),
                if (passwordMode) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Adresse e-mail'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _passwordLogin(),
                    decoration: const InputDecoration(labelText: 'Mot de passe'),
                  ),
                ] else if (!codeSent)
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(labelText: 'Adresse e-mail'),
                  )
                else
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 10,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verify(),
                    style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(labelText: 'Code reçu par e-mail'),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: TextStyle(color: c.red, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : (passwordMode ? _passwordLogin : codeSent ? _verify : _send),
                  child: busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(passwordMode ? 'Se connecter' : codeSent ? 'Valider le code' : 'Recevoir mon code'),
                ),
                if (!codeSent)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              passwordMode = !passwordMode;
                              error = null;
                            }),
                    child: Text(passwordMode ? 'Recevoir plutôt un code par e-mail' : 'Compte de démonstration : mot de passe'),
                  ),
                if (codeSent) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              codeSent = false;
                              _code.clear();
                              error = null;
                            }),
                    child: const Text('Changer d’adresse ou renvoyer un code'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
