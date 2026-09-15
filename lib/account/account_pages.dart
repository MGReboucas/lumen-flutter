import 'package:flutter/material.dart';

import '../checkout/checkout_pages.dart';
import 'account_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.account, required this.onOrders});
  final AccountController account;
  final VoidCallback onOrders;
  Future<void> _auth(BuildContext context, bool register) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthPage(account: account, register: register),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: account,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Seu espaço Lumen',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sua conta, seus favoritos, suas escolhas.',
          style: TextStyle(color: Color(0xFFA7A097)),
        ),
        const SizedBox(height: 28),
        if (account.loading)
          const LinearProgressIndicator()
        else if (account.error != null)
          RetryNotice(account.error!, account.initialize),
        const CircleAvatar(
          radius: 38,
          child: Icon(Icons.person_outline, size: 40),
        ),
        const SizedBox(height: 18),
        Text(
          account.user?['email'] as String? ?? 'Bem-vinda à Lumen',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        if (account.user == null) ...[
          const Text(
            'Entre para acessar sua sacola, seus pedidos e favoritos em outros aparelhos.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: account.loading ? null : () => _auth(context, false),
            child: const Text('ENTRAR'),
          ),
          OutlinedButton(
            onPressed: account.loading ? null : () => _auth(context, true),
            child: const Text('CRIAR CONTA'),
          ),
        ],
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Meus pedidos'),
            subtitle: Text(
              account.user == null
                  ? 'Compras desta sessão'
                  : 'Acompanhe suas compras',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOrders,
          ),
        ),
        if (account.user != null) ...[
          const SizedBox(height: 12),
          const Text(
            'Sua sessão dura até 7 dias. Ao sair, seus pedidos e favoritos continuam salvos na conta.',
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('SAIR DA CONTA'),
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sair da conta?'),
                  content: const Text(
                    'Você pode entrar novamente a qualquer momento.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('VOLTAR'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('SAIR'),
                    ),
                  ],
                ),
              );
              if (yes != true) return;
              try {
                await account.logout();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(errorText(e))));
                }
              }
            },
          ),
        ],
      ],
    ),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.account, this.register = false});
  final AccountController account;
  final bool register;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late bool _register;
  bool _busy = false, _obscure = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _register = widget.register;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.account.signIn(_email.text, _password.text, _register);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_register ? 'Criar conta' : 'Entrar na Lumen')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 44,
                    color: Color(0xFFD9B66A),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _register
                        ? 'Sua essência tem lugar aqui.'
                        : 'Que bom ter você de volta.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _register
                        ? 'Cadastre seu e-mail e uma senha para guardar suas escolhas.'
                        : 'Entre com seu e-mail e senha para continuar.',
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    key: const ValueKey('auth-email'),
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) =>
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v!.trim())
                        ? null
                        : 'Informe um e-mail válido.',
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('auth-password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscure,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      helperText:
                          'De 12 a 128 caracteres. Pode usar uma frase.',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => v!.length < 12 || v.length > 128
                        ? 'Use de 12 a 128 caracteres.'
                        : null,
                  ),
                  if (_register) ...[
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const ValueKey('auth-confirm'),
                      controller: _confirm,
                      enabled: !_busy,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar senha',
                      ),
                      validator: (v) => v != _password.text
                          ? 'As senhas não conferem.'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'No primeiro acesso, a sacola atual fica vinculada à conta. Se você já tem uma sacola na conta, ela será retomada.',
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        key: const ValueKey('auth-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'AGUARDE...'
                          : _register
                          ? 'CADASTRAR'
                          : 'ENTRAR',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _error = null;
                            _form.currentState!.reset();
                          }),
                    child: Text(
                      _register
                          ? 'Já tenho uma conta'
                          : 'Ainda não tenho conta',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
