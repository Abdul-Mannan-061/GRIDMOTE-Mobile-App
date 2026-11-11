import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _identifier = TextEditingController();
  final _password = TextEditingController();

  final _email1 = TextEditingController();
  final _password1 = TextEditingController();
  final _confirm1 = TextEditingController();

  final _email2 = TextEditingController();
  final _password2 = TextEditingController();
  final _confirm2 = TextEditingController();

  bool _rememberMe = false;
  bool _busy = false;

  String? _error;
  String? _notice;

  @override
  void dispose() {
    for (final controller in [
      _identifier,
      _password,
      _email1,
      _password1,
      _confirm1,
      _email2,
      _password2,
      _confirm2,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final auth = AuthService.instance;
    final settingUp = !auth.hasAccounts;

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      if (settingUp) {
        await auth.setupAccounts(
          firstEmail: _email1.text,
          firstPassword: _password1.text,
          secondEmail: _email2.text,
          secondPassword: _password2.text,
        );

        if (!mounted) return;

        _identifier.text = _email1.text.trim();

        for (final controller in [
          _password1,
          _confirm1,
          _password2,
          _confirm2,
        ]) {
          controller.clear();
        }

        setState(() {
          _notice = 'Your accounts are ready. Sign in to continue.';
        });
      } else {
        await auth.login(
          identifier: _identifier.text,
          password: _password.text,
          rememberMe: _rememberMe,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    if (!AuthService.validEmail(value ?? '')) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';

    if (password.length < 8 ||
        password.length > 128 ||
        password.trim().isEmpty) {
      return 'Use 8 to 128 characters.';
    }

    return null;
  }

  void _selectUser(String name) {
    if (_busy) return;

    setState(() {
      _identifier.text = name;
      _password.clear();
      _error = null;
    });
  }

  Widget _userChip(String name, String initials) {
    final colors = Theme.of(context).colorScheme;
    final selected =
        _identifier.text.trim().toLowerCase() == name.toLowerCase();

    return ChoiceChip(
      selected: selected,
      onSelected: _busy ? null : (_) => _selectUser(name),
      showCheckmark: false,
      avatar: CircleAvatar(
        backgroundColor: selected
            ? colors.primary
            : colors.primaryContainer,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: selected
                ? colors.onPrimary
                : colors.onPrimaryContainer,
          ),
        ),
      ),
      label: Text(name),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 9,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _accountFields({
    required String name,
    required String number,
    required TextEditingController email,
    required TextEditingController password,
    required TextEditingController confirmation,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Text(number),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: _validateEmail,
          ),
          const SizedBox(height: 14),
          _PasswordField(
            controller: password,
            label: 'Password',
            validator: _validateNewPassword,
          ),
          const SizedBox(height: 14),
          _PasswordField(
            controller: confirmation,
            label: 'Confirm password',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirm your password.';
              }

              if (value != password.text) {
                return 'Passwords do not match.';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _messageBox(String message, {required bool isError}) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.info_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 20,
            color: isError
                ? colors.onErrorContainer
                : colors.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError
                    ? colors.onErrorContainer
                    : colors.onPrimaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final colors = baseTheme.colorScheme;
    final dark = baseTheme.brightness == Brightness.dark;
    final settingUp = !AuthService.instance.hasAccounts;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );

    final formTheme = baseTheme.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? const Color(0xFF202D42)
            : const Color(0xFFF2F6FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.6),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.error, width: 1.6),
        ),
        errorMaxLines: 2,
      ),
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [
              Color(0xFF10233B),
              Color(0xFF0B1120),
              Color(0xFF102C35),
            ]
                : const [
              Color(0xFFE4F3FF),
              Color(0xFFF5F7FC),
              Color(0xFFE4F7F3),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            final progress =
                            MediaQuery.of(context).disableAnimations
                                ? 1.0
                                : value;

                            return Opacity(
                              opacity: progress,
                              child: Transform.translate(
                                offset: Offset(0, 18 * (1 - progress)),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _BrandHeader(dark: dark),
                              const SizedBox(height: 28),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? const Color(0xFF152136)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: dark
                                        ? const Color(0xFF2A3B53)
                                        : const Color(0xFFE4EBF3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(
                                        dark ? 35 : 12,
                                      ),
                                      blurRadius: 30,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Theme(
                                  data: formTheme,
                                  child: AbsorbPointer(
                                    absorbing: _busy,
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            settingUp
                                                ? 'Meet your team.'
                                                : 'Welcome back.',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.7,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            settingUp
                                                ? 'Set up two accounts to '
                                                'make this space yours.'
                                                : 'Your devices and layouts '
                                                'are waiting for you.',
                                            style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          if (settingUp) ...[
                                            _accountFields(
                                              name: 'Abdul Mannan',
                                              number: '1',
                                              email: _email1,
                                              password: _password1,
                                              confirmation: _confirm1,
                                            ),
                                            const SizedBox(height: 18),
                                            _accountFields(
                                              name: 'Muneeb',
                                              number: '2',
                                              email: _email2,
                                              password: _password2,
                                              confirmation: _confirm2,
                                            ),
                                            const SizedBox(height: 18),
                                            Text(
                                              'Use different email addresses. '
                                                  'Existing layouts will be added '
                                                  'to Abdul Mannan’s account.',
                                              style: TextStyle(
                                                color:
                                                colors.onSurfaceVariant,
                                                fontSize: 12,
                                                height: 1.5,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Email is not verified. Keep '
                                                  'your passwords safe; offline '
                                                  'email recovery is unavailable.',
                                              style: TextStyle(
                                                color:
                                                colors.onSurfaceVariant,
                                                fontSize: 12,
                                                height: 1.5,
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                              'CHOOSE YOUR ACCOUNT',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.5,
                                                color:
                                                colors.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 8,
                                              children: [
                                                _userChip(
                                                  'Abdul Mannan',
                                                  'AM',
                                                ),
                                                _userChip('Muneeb', 'M'),
                                              ],
                                            ),
                                            const SizedBox(height: 22),
                                            TextFormField(
                                              controller: _identifier,
                                              autocorrect: false,
                                              textInputAction:
                                              TextInputAction.next,
                                              onChanged: (_) {
                                                setState(() {});
                                              },
                                              decoration:
                                              const InputDecoration(
                                                labelText: 'Name or email',
                                                prefixIcon: Icon(
                                                  Icons.person_outline_rounded,
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return 'Enter your name '
                                                      'or email.';
                                                }

                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            _PasswordField(
                                              controller: _password,
                                              label: 'Password',
                                              onSubmitted: _submit,
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Enter your password.';
                                                }

                                                if (value.length > 128) {
                                                  return 'Password is too long.';
                                                }

                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                            CheckboxListTile(
                                              contentPadding: EdgeInsets.zero,
                                              controlAffinity:
                                              ListTileControlAffinity
                                                  .leading,
                                              title: const Text(
                                                'Keep me signed in',
                                                style: TextStyle(fontSize: 13),
                                              ),
                                              value: _rememberMe,
                                              onChanged: (value) {
                                                setState(() {
                                                  _rememberMe = value ?? false;
                                                });
                                              },
                                            ),
                                          ],
                                          if (_error != null) ...[
                                            const SizedBox(height: 14),
                                            _messageBox(
                                              _error!,
                                              isError: true,
                                            ),
                                          ],
                                          if (_notice != null) ...[
                                            const SizedBox(height: 14),
                                            _messageBox(
                                              _notice!,
                                              isError: false,
                                            ),
                                          ],
                                          const SizedBox(height: 20),
                                          FilledButton(
                                            onPressed: _busy ? null : _submit,
                                            style: FilledButton.styleFrom(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 18,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              child: _busy
                                                  ? const Row(
                                                key: ValueKey('loading'),
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                                children: [
                                                  SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text('Please wait…'),
                                                ],
                                              )
                                                  : Row(
                                                key: const ValueKey(
                                                  'ready',
                                                ),
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      settingUp
                                                          ? 'Create accounts'
                                                          : 'Sign in',
                                                      style:
                                                      const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                        FontWeight
                                                            .w700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    width: 10,
                                                  ),
                                                  const Icon(
                                                    Icons
                                                        .arrow_forward_rounded,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      'Offline access · On this device',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF38BDF8),
                Color(0xFF2563EB),
              ],
            ),
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withAlpha(45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.dashboard_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'GRIDMOTE',
          style: TextStyle(
            fontSize: 25,
            letterSpacing: 4,
            fontWeight: FontWeight.w800,
            color: dark
                ? const Color(0xFFF1F5F9)
                : const Color(0xFF14233A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Design. Connect. Control.',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final VoidCallback? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: widget.onSubmitted == null
          ? null
          : (_) => widget.onSubmitted!(),
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(
            _hidden
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 21,
          ),
        ),
      ),
    );
  }
}