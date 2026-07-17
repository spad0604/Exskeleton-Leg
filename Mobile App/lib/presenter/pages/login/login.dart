import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/languages/translation_keys.g.dart';
import 'package:flutter_starter/presenter/navigation/navigation.dart';
import 'package:flutter_starter/presenter/pages/login/login_bloc.dart';
import 'package:flutter_starter/presenter/pages/login/login_event.dart';
import 'package:flutter_starter/presenter/pages/login/login_selector.dart';
import 'package:flutter_starter/presenter/pages/login/login_state.dart';
import 'package:flutter_starter/presenter/widgets/loading_indicator.dart';

@RoutePage()
class LoginPage extends StatefulWidget implements AutoRouteWrapper {
  const LoginPage();

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider<LoginBloc>(
      create: (ctx) => provider.get<LoginBloc>(),
      child: this,
    );
  }

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  LoginBloc get _bloc => context.read<LoginBloc>();

  void _onUsernameChanged(String username) {
    _bloc.add(LoginUsernameChanged(username));
  }

  void _onPasswordChanged(String password) {
    _bloc.add(LoginPasswordChanged(password));
  }

  void _onLoginPressed() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _bloc.add(const LoginStarted());
  }

  void _onSuccess(BuildContext context, LoginState state) {
    context.router.replaceAll([const HomeRoute()]);
  }

  void _onError(BuildContext context, LoginState state) {
    final errorMessage = state.error?.message;

    if (errorMessage == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(errorMessage)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        LoginSuccessListener(listener: _onSuccess),
        LoginFailureListener(listener: _onError),
      ],
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.accessibility_new_rounded,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                          semanticLabel: 'Exoskeleton Leg',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chào mừng trở lại',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Đăng nhập để tiếp tục chương trình tập của bạn.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.email_outlined),
                            labelText: 'Email',
                          ),
                          validator: _validateEmail,
                          onChanged: _onUsernameChanged,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            labelText: tr(LocaleKeys.Password),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Hiện mật khẩu'
                                  : 'Ẩn mật khẩu',
                              onPressed: () => setState(() {
                                _obscurePassword = !_obscurePassword;
                              }),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) => (value?.isEmpty ?? true)
                              ? 'Vui lòng nhập mật khẩu.'
                              : null,
                          onFieldSubmitted: (_) => _onLoginPressed(),
                          onChanged: _onPasswordChanged,
                        ),
                        const SizedBox(height: 24),
                        LoginStatusSelector(
                          builder: (status) {
                            final submitting = status == LoginStatus.submitting;
                            return FilledButton(
                              onPressed: submitting ? null : _onLoginPressed,
                              child: submitting
                                  ? const AppFilledButtonLoadingIndicator()
                                  : Text(tr(LocaleKeys.Login)),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              context.router.pushNamed('/auth/register'),
                          child: const Text('Chưa có tài khoản? Đăng ký'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty ||
        !email.contains('@') ||
        !email.split('@').last.contains('.')) {
      return 'Vui lòng nhập email hợp lệ.';
    }
    return null;
  }
}
