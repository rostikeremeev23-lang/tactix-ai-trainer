import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../services/auth_service.dart';
import 'user_setup_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _callsign = TextEditingController();
  final _invite = TextEditingController();

  bool _register = false;
  bool _loading = false;

  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _callsign.dispose();
    _invite.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    try {
      final session = UserSessionScope.read(context);

      if (_register) {
        await session.register(
          email: _email.text,
          password: _password.text,
          firstName: _firstName.text,
          callsign: _callsign.text,
          inviteCode: _invite.text,
        );

        _notice = 'Регистрация завершена.';
      } else {
        await session.login(_email.text, _password.text);

        _notice = 'Вход выполнен.';
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_notice!)));
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось выполнить запрос. Проверьте подключение к сети.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите $label';
    }

    return null;
  }

  Future<void> _openOfflineProfile() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const UserSetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _register;

    return Scaffold(
      backgroundColor: TactixTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: TactixTheme.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: TactixTheme.line),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: TactixTheme.gold,
                        size: 42,
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'TACTIX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        isRegister ? 'РЕГИСТРАЦИЯ ПО ПРИГЛАШЕНИЮ' : 'ВХОД',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: TactixTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                        ),
                      ),

                      const SizedBox(height: 22),

                      if (isRegister) ...[
                        _field(
                          _firstName,
                          'Имя',
                          Icons.person_outline,
                          validator: (value) => _required(value, 'имя'),
                        ),

                        const SizedBox(height: 12),

                        _field(
                          _callsign,
                          'Позывной',
                          Icons.badge_outlined,
                          validator: (value) => _required(value, 'позывной'),
                        ),

                        const SizedBox(height: 12),
                      ],

                      _field(
                        _email,
                        'Email',
                        Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Введите корректный Email';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      _field(
                        _password,
                        'Пароль',
                        Icons.lock_outline,
                        obscure: true,
                        textInputAction: isRegister
                            ? TextInputAction.next
                            : TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите пароль';
                          }

                          if (isRegister && value.length < 12) {
                            return 'Используйте минимум 12 символов';
                          }

                          return null;
                        },
                      ),

                      if (isRegister) ...[
                        const SizedBox(height: 12),

                        _field(
                          _invite,
                          'Код приглашения',
                          Icons.confirmation_number_outlined,
                          validator: (value) =>
                              _required(value, 'код приглашения'),
                        ),

                        const SizedBox(height: 9),

                        const Text(
                          'Организация и роль определяются '
                          'кодом приглашения.',
                          style: TextStyle(
                            color: TactixTheme.textMuted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _Message(text: _error!, error: true),
                      ],

                      if (_notice != null && _error == null) ...[
                        const SizedBox(height: 14),
                        _Message(text: _notice!, error: false),
                      ],

                      const SizedBox(height: 20),

                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: TactixTheme.gold,
                          foregroundColor: TactixTheme.bg,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isRegister ? 'СОЗДАТЬ АККАУНТ' : 'ВОЙТИ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .6,
                                ),
                              ),
                      ),

                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() {
                                  _register = !_register;
                                  _error = null;
                                  _notice = null;
                                });
                              },
                        child: Text(
                          isRegister
                              ? 'Уже есть аккаунт? Войти'
                              : 'Нет аккаунта? Зарегистрироваться',
                        ),
                      ),

                      const Divider(color: TactixTheme.line, height: 28),

                      const Row(
                        children: [
                          Expanded(child: Divider(color: TactixTheme.line)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OFFLINE',
                              style: TextStyle(
                                color: TactixTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: TactixTheme.line)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: _loading ? null : _openOfflineProfile,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: TactixTheme.gold),
                        ),
                        icon: const Icon(
                          Icons.offline_bolt_outlined,
                          color: TactixTheme.gold,
                        ),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'РАБОТАТЬ ОФЛАЙН',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: .6,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Интернет не требуется. Профиль и '
                        'данные сохраняются локально на этом устройстве.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TactixTheme.textMuted,
                          fontSize: 11,
                          height: 1.4,
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

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autocorrect: false,
      enableSuggestions: !obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: TactixTheme.panel2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
      ),
      validator: validator,
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final bool error;

  const _Message({required this.text, required this.error});

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFFF7B78) : TactixTheme.cyan;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 13, height: 1.4),
      ),
    );
  }
}
