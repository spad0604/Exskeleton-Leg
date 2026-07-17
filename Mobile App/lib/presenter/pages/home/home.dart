import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_event.dart';
import 'package:flutter_starter/di.dart';

@RoutePage()
class HomePage extends StatelessWidget implements AutoRouteWrapper {
  const HomePage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) => BlocProvider(
    create: (_) => LogoutCubit(provider.get<AuthRepository>()),
    child: this,
  );

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthBloc>().state.account;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hôm nay'),
        actions: [
          BlocConsumer<LogoutCubit, LogoutStatus>(
            listener: (context, status) {
              if (status == LogoutStatus.success) {
                context.read<AuthBloc>().add(const AuthLoggedOut());
              }
            },
            builder: (context, status) => IconButton(
              tooltip: 'Đăng xuất',
              onPressed: status == LogoutStatus.submitting
                  ? null
                  : () => context.read<LogoutCubit>().logout(),
              icon: const Icon(Icons.logout),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Xin chào, ${account?.displayName ?? 'bạn'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tài khoản của bạn đã sẵn sàng. Các luồng thiết bị và bài tập sẽ được nối ở lát triển khai tiếp theo.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

enum LogoutStatus { initial, submitting, success }

class LogoutCubit extends Cubit<LogoutStatus> {
  final AuthRepository _authRepository;

  LogoutCubit(this._authRepository) : super(LogoutStatus.initial);

  Future<void> logout() async {
    if (state == LogoutStatus.submitting) return;
    emit(LogoutStatus.submitting);
    try {
      await _authRepository.logout();
    } finally {
      emit(LogoutStatus.success);
    }
  }
}
