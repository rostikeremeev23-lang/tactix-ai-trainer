import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/user_session_scope.dart';
import '../../models/app_user.dart';

class UserSetupScreen extends StatefulWidget {
  const UserSetupScreen({
    super.key,
  });

  @override
  State<UserSetupScreen> createState() =>
      _UserSetupScreenState();
}

class _UserSetupScreenState
    extends State<UserSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _callsignController =
      TextEditingController();

  final _fullNameController =
      TextEditingController();

  final _unitController =
      TextEditingController();

  UserRole _role = UserRole.trainee;
  bool _saving = false;

  @override
  void dispose() {
    _callsignController.dispose();
    _fullNameController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final user = AppUser(
      id: DateTime.now()
          .microsecondsSinceEpoch
          .toString(),
      callsign:
          _callsignController.text.trim(),
      fullName:
          _fullNameController.text.trim(),
      unitName:
          _unitController.text.trim(),
      role: _role,
      createdAt: DateTime.now(),
    );

    await UserSessionScope.read(
      context,
    ).signIn(user);

    if (!mounted) return;

    setState(() {
      _saving = false;
    });
  }

  InputDecoration _decoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TactixTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 520,
              ),
              child: Container(
                padding:
                    const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: TactixTheme.panel,
                  borderRadius:
                      BorderRadius.circular(20),
                  border: Border.all(
                    color: TactixTheme.line,
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: TactixTheme.gold,
                        size: 42,
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      const Text(
                        'TACTIX',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      const Text(
                        'ПРОФИЛЬ ДОСТУПА',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color:
                              TactixTheme.textMuted,
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(
                        height: 26,
                      ),
                      TextFormField(
                        controller:
                            _callsignController,
                        textInputAction:
                            TextInputAction.next,
                        decoration: _decoration(
                          'Позывной',
                          Icons.badge_outlined,
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Введите позывной';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextFormField(
                        controller:
                            _fullNameController,
                        textInputAction:
                            TextInputAction.next,
                        decoration: _decoration(
                          'ФИО',
                          Icons.person_outline,
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Введите ФИО';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextFormField(
                        controller:
                            _unitController,
                        textInputAction:
                            TextInputAction.next,
                        decoration: _decoration(
                          'Подразделение',
                          Icons.groups_outlined,
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      DropdownButtonFormField<
                          UserRole>(
                        initialValue: _role,
                        decoration: _decoration(
                          'Роль',
                          Icons.admin_panel_settings_outlined,
                        ),
                        items: UserRole.values
                            .map(
                              (role) =>
                                  DropdownMenuItem(
                                value: role,
                                child: Text(
                                  role.label,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _role = value;
                          });
                        },
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      const Text(
                        'В пилотной сборке роль выбирается локально. '
                        'В рабочей версии права доступа будут назначаться администратором.',
                        style: TextStyle(
                          color:
                              TactixTheme.textMuted,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(
                        height: 22,
                      ),
                      FilledButton.icon(
                        onPressed:
                            _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.login_rounded,
                              ),
                        label: Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 14,
                          ),
                          child: Text(
                            _saving
                                ? 'СОХРАНЕНИЕ...'
                                : 'ВОЙТИ В TACTIX',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
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

