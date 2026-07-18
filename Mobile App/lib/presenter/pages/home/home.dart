import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/entities/patient_home.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';
import 'package:flutter_starter/data/repositories/home_repository/home_repository.default.dart';
import 'package:flutter_starter/data/sources/network/network.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_event.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/pages/home/home_cubit.dart';

@RoutePage()
class HomePage extends StatelessWidget implements AutoRouteWrapper {
  const HomePage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    final patientId = context.read<AuthBloc>().state.account?.id;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LogoutCubit(provider.get<AuthRepository>()),
        ),
        BlocProvider(
          create: (_) => HomeCubit(
            repository: DefaultHomeRepository(
              networkDataSource: provider.get<NetworkDataSource>(),
            ),
          )..load(patientId),
        ),
      ],
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hôm nay'),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
          ),
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
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            return switch (state.status) {
              HomeStatus.initial || HomeStatus.loading => const _HomeLoading(),
              HomeStatus.failure => _HomeError(
                  onRetry: () => context.read<HomeCubit>().load(
                        context.read<AuthBloc>().state.account?.id,
                      ),
                ),
              HomeStatus.content => _HomeContent(home: state.home),
            };
          },
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final PatientHome? home;

  const _HomeContent({required this.home});

  @override
  Widget build(BuildContext context) {
    final data = home;
    if (data == null) {
      return _HomeError(onRetry: () {});
    }

    final nextPlanItem = data.nextPlanItem;
    final device = data.device;
    final metrics = data.todayMetrics;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Xin chào, ${data.patient.displayName}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Hôm nay mình tập nhẹ và chắc nhé.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        _HomeStatusBanner(device: device),
        const SizedBox(height: 20),
        if (nextPlanItem == null)
          const _EmptyPlanCard()
        else
          _NextExerciseCard(planItem: nextPlanItem),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _TodayMetric(
                icon: Icons.task_alt,
                value: '${metrics.completedCount} / ${metrics.plannedCount}',
                label: 'Bài đã tập',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TodayMetric(
                icon: Icons.timer_outlined,
                value: _minutesLabel(metrics.activeSeconds),
                label: 'Thời gian',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TodayMetric(
          icon: Icons.check_circle_outline,
          value: _ratioLabel(metrics.correctnessRatio),
          label: 'Động tác đạt',
        ),
        const SizedBox(height: 24),
        Text('Cần chú ý', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (data.openAlerts.isEmpty)
          const _NoAlertPreview()
        else
          _AlertPreview(alert: data.openAlerts.first),
      ],
    );
  }

  String _minutesLabel(int activeSeconds) {
    final minutes = (activeSeconds / 60).round();
    return '$minutes phút';
  }

  String _ratioLabel(double? ratio) {
    if (ratio == null) return 'Chưa đủ dữ liệu';
    return '${(ratio * 100).round()}%';
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(width: 180, height: 28, color: colorScheme.surfaceContainer),
        const SizedBox(height: 12),
        Container(width: 260, height: 20, color: colorScheme.surfaceContainer),
        const SizedBox(height: 20),
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: i == 1 ? 160 : 88,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  final VoidCallback onRetry;

  const _HomeError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa tải được dữ liệu hôm nay',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Kiểm tra kết nối hoặc thử lại sau.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeStatusBanner extends StatelessWidget {
  final HomeDevice? device;

  const _HomeStatusBanner({required this.device});

  @override
  Widget build(BuildContext context) {
    final currentDevice = device;
    if (currentDevice == null) {
      return _StatusContainer(
        icon: Icons.settings_remote_outlined,
        foreground: Theme.of(context).colorScheme.primary,
        background: Theme.of(context).colorScheme.primaryContainer,
        title: 'Chưa ghép thiết bị',
        message: 'Ghép thiết bị để bắt đầu bài tập có hỗ trợ.',
      );
    }

    final ready = currentDevice.readiness.state == 'ready' && currentDevice.online;
    return _StatusContainer(
      icon: ready ? Icons.check_circle : Icons.cloud_off,
      foreground: ready ? const Color(0xFF146C2E) : const Color(0xFF5E5E65),
      background: ready ? const Color(0xFFC4EED0) : const Color(0xFFE5E1E6),
      title: ready ? 'Thiết bị đã sẵn sàng' : 'Thiết bị chưa sẵn sàng',
      message: '${currentDevice.serialNumber} - Pin ${currentDevice.batteryPercent}%',
    );
  }
}

class _StatusContainer extends StatelessWidget {
  final IconData icon;
  final Color foreground;
  final Color background;
  final String title;
  final String message;

  const _StatusContainer({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Xem thiết bị',
            onPressed: () {},
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _NextExerciseCard extends StatelessWidget {
  final NextPlanItem planItem;

  const _NextExerciseCard({required this.planItem});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.accessibility_new,
                  color: colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    planItem.exerciseName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${planItem.target.sets} hiệp x ${planItem.target.repetitionsPerSet} lần - ${_minutesLabel(planItem.estimatedDurationSeconds)}',
            ),
            const SizedBox(height: 4),
            Text('Mức hỗ trợ: ${_assistanceLabel(planItem.assistanceLevel)}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu bài tập'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _minutesLabel(int seconds) => 'khoảng ${(seconds / 60).round()} phút';

  String _assistanceLabel(String value) {
    return switch (value) {
      'low' => 'thấp',
      'medium' => 'vừa',
      'high' => 'cao',
      _ => value,
    };
  }
}

class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hôm nay chưa có bài tập',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Bạn có thể xem danh sách bài tập đã được duyệt.'),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () {},
              icon: const Icon(Icons.fitness_center),
              label: const Text('Xem bài tập'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _TodayMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _AlertPreview extends StatelessWidget {
  final HomeAlert alert;

  const _AlertPreview({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE08A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFF765A00)),
          const SizedBox(width: 12),
          Expanded(child: Text(alert.title)),
          TextButton(
            onPressed: () {},
            child: const Text('Xem'),
          ),
        ],
      ),
    );
  }
}

class _NoAlertPreview extends StatelessWidget {
  const _NoAlertPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline),
          SizedBox(width: 12),
          Expanded(child: Text('Không có cảnh báo cần xem.')),
        ],
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
