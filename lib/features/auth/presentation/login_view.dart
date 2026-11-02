import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_runtime.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import 'auth_view_model.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});
  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _device = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _hide = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _device.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(runtimeProvider);
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/brand/logo.png',
                        height: 100,
                        semanticLabel: 'Ponto Aqui',
                      ),
                      const SizedBox(height: 36),
                      Text(
                        'Sua jornada começa aqui.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Brand.navy,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Entre com a conta fornecida pela sua empresa.',
                      ),
                      const SizedBox(height: 28),
                      if (auth.hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            auth.error is AppFailure
                                ? (auth.error as AppFailure).message
                                : 'Não foi possível restaurar a sessão. Entre novamente.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (value) =>
                            value == null || !value.contains('@')
                            ? 'Informe seu e-mail.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: _hide,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hide ? 'Mostrar senha' : 'Ocultar senha',
                            onPressed: () => setState(() => _hide = !_hide),
                            icon: Icon(
                              _hide
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Informe sua senha.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _device,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'ID cadastrado do aparelho',
                          helperText: 'Solicite este ID ao administrador.',
                          helperMaxLines: 2,
                          prefixIcon: Icon(Icons.phonelink_lock_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Informe o ID fornecido pela empresa.'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                if (!_form.currentState!.validate()) return;
                                FocusScope.of(context).unfocus();
                                final password = _password.text;
                                _password.clear();
                                await ref
                                    .read(authProvider.notifier)
                                    .login(
                                      _email.text,
                                      password,
                                      _device.text.trim(),
                                    );
                              },
                        child: const Text('Entrar'),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Primeiro acesso neste aparelho',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'O cadastro precisa ser concluído pela empresa. Compartilhe o identificador desta instalação com o administrador.',
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                runtime.installationUuid,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: runtime.installationUuid,
                                    ),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Identificador copiado.'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copiar identificador'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        runtime.config.origin,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
