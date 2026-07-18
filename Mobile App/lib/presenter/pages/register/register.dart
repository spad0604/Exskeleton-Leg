import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_event.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/navigation/navigation.dart';
import 'package:flutter_starter/presenter/pages/auth_widgets.dart';
import 'package:flutter_starter/presenter/pages/register/register_cubit.dart';

@RoutePage()
class RegisterPage extends StatefulWidget implements AutoRouteWrapper {
  const RegisterPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) => BlocProvider(
        create: (_) => RegisterCubit(provider.get<AuthRepository>()),
        child: this,
      );

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _acceptedTerms = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần xác nhận đã đọc điều khoản sử dụng.'),
        ),
      );
      return;
    }
    context.read<RegisterCubit>().register(
          displayName: _displayNameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          acceptedTerms: _acceptedTerms,
        );
  }

  void _onSocialPressed(String providerName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$providerName sẽ được hỗ trợ trong bản tiếp theo.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegisterCubit, RegisterState>(
      listener: (context, state) async {
        if (state.status == RegisterStatus.success && state.account != null) {
          final authBloc = context.read<AuthBloc>();
          final authenticated = authBloc.stream.firstWhere(
            (authState) => authState.loggedIn,
          );
          authBloc.add(AuthLoggedIn(state.account!));
          await authenticated;
          if (!context.mounted) return;
          context.router.replaceAll([const PatientShellRoute()]);
        } else if (state.status == RegisterStatus.failure) {
          final message = state.error?.message;
          if (message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(tr(message))));
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Tạo tài khoản')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .shadow
                            .withValues(alpha: 0.08),
                        offset: const Offset(0, 18),
                        blurRadius: 44,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuthHeader(
                            icon: Icons.health_and_safety_outlined,
                            title: 'Bắt đầu tập luyện an toàn',
                            subtitle:
                                'Tài khoản mới được tạo với vai trò người tập.',
                          ),
                          const SizedBox(height: 30),
                          AuthTextFormField(
                            label: 'Họ và tên',
                            hintText: 'Nguyễn An',
                            prefixIcon: Icons.person_outline,
                            controller: _displayNameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (value) =>
                                (value?.trim().length ?? 0) < 2
                                    ? 'Vui lòng nhập họ và tên.'
                                    : null,
                          ),
                          const SizedBox(height: 18),
                          AuthTextFormField(
                            label: 'Email',
                            hintText: 'user@example.com',
                            prefixIcon: Icons.email_outlined,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              return email.contains('@') &&
                                      email.split('@').last.contains('.')
                                  ? null
                                  : 'Vui lòng nhập email hợp lệ.';
                            },
                          ),
                          const SizedBox(height: 18),
                          AuthTextFormField(
                            label: 'Mật khẩu',
                            hintText: 'Tạo mật khẩu',
                            prefixIcon: Icons.lock_outline,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            helperText: 'Từ 8 đến 128 ký tự.',
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
                            validator: (value) {
                              final length = value?.characters.length ?? 0;
                              return length < 8 || length > 128
                                  ? 'Mật khẩu cần từ 8 đến 128 ký tự.'
                                  : null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _acceptedTerms,
                            onChanged: (value) => setState(() {
                              _acceptedTerms = value ?? false;
                            }),
                            title: const Text(
                              'Tôi đã đọc và đồng ý với điều khoản sử dụng phiên bản 2026-01.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          BlocBuilder<RegisterCubit, RegisterState>(
                            builder: (context, state) {
                              final submitting =
                                  state.status == RegisterStatus.submitting;
                              return FilledButton(
                                onPressed: submitting ? null : _submit,
                                child: submitting
                                    ? const SizedBox.square(
                                        dimension: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Đăng ký'),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          SocialAuthButtons(
                            onGooglePressed: () => _onSocialPressed('Google'),
                            onFacebookPressed: () =>
                                _onSocialPressed('Facebook'),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () => context.router.maybePop(),
                            child: const Text('Đã có tài khoản? Đăng nhập'),
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
      ),
    );
  }
}
