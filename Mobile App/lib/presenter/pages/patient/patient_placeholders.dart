import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_event.dart';
import 'package:flutter_starter/di.dart';

@RoutePage()
class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PatientTabScaffold(
      title: 'Bài tập',
      actions: [
        IconButton(
          tooltip: 'Lọc bài tập',
          onPressed: () {},
          icon: const Icon(Icons.filter_list),
        ),
      ],
      children: const [
        _SegmentHeader(labels: ['Hôm nay', 'Tất cả']),
        SizedBox(height: 16),
        _ExerciseCard(
          title: 'Đứng lên và ngồi xuống',
          subtitle: '2 hiệp x 8 lần',
          meta: 'Khoảng 10 phút',
          chip: 'Hôm nay',
        ),
        SizedBox(height: 12),
        _ExerciseCard(
          title: 'Nâng gối có hỗ trợ',
          subtitle: '3 hiệp x 6 lần mỗi bên',
          meta: 'Hỗ trợ thấp',
          chip: 'Cần thiết bị',
        ),
        SizedBox(height: 12),
        _ExerciseCard(
          title: 'Duỗi hông chậm',
          subtitle: 'Giữ 5 giây mỗi lần',
          meta: 'Tập kiểm soát',
          chip: 'Tất cả',
        ),
      ],
    );
  }
}

@RoutePage()
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _PatientTabScaffold(
      title: 'Tiến độ',
      children: [
        const _SegmentHeader(labels: ['Tuần', 'Tháng']),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Hoàn thành',
                value: '6 / 8',
                icon: Icons.task_alt,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Thời gian',
                value: '54 phút',
                icon: Icons.timer_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _MetricCard(
          label: 'Động tác đạt',
          value: '81%',
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(height: 24),
        Text('Xu hướng', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          height: 168,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: CustomPaint(
            painter: _TrendPainter(colorScheme.primary),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 24),
        Text('Lịch sử gần đây', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const _SessionTile(
          title: 'Đứng lên và ngồi xuống',
          subtitle: 'Hôm nay - Hoàn thành 15 / 16 lần',
          icon: Icons.done,
        ),
        const _SessionTile(
          title: 'Duỗi hông chậm',
          subtitle: 'Hôm qua - Buổi tập đã dừng an toàn',
          icon: Icons.report_gmailerrorred_outlined,
        ),
      ],
    );
  }
}

@RoutePage()
class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PatientTabScaffold(
      title: 'Thiết bị',
      children: const [
        _StatusBanner(
          icon: Icons.check_circle,
          title: 'Thiết bị đã sẵn sàng',
          message: 'EXO-2026-000123 - Pin 78%',
          tone: _StatusTone.ready,
        ),
        SizedBox(height: 16),
        _InfoTile(
          icon: Icons.settings_remote_outlined,
          title: 'Exoskeleton Leg v1',
          subtitle: 'Firmware 1.2.0 - Kết nối 08:00',
        ),
        _InfoTile(
          icon: Icons.sensors_outlined,
          title: 'Cảm biến hoạt động ổn định',
          subtitle: 'Hông trái/phải, gối trái/phải đều sẵn sàng',
        ),
        _InfoTile(
          icon: Icons.tune_outlined,
          title: 'Hiệu chỉnh còn hiệu lực',
          subtitle: 'Hết hạn sau 31 ngày',
        ),
        SizedBox(height: 16),
        _ActionRow(
          primaryLabel: 'Hiệu chỉnh',
          secondaryLabel: 'Chẩn đoán',
          primaryIcon: Icons.straighten,
          secondaryIcon: Icons.fact_check_outlined,
        ),
      ],
    );
  }
}

@RoutePage()
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthBloc>().state.account;

    return _PatientTabScaffold(
      title: 'Cá nhân',
      children: [
        _InfoTile(
          icon: Icons.account_circle_outlined,
          title: account?.displayName ?? 'Người tập',
          subtitle: 'Tài khoản patient',
        ),
        const SizedBox(height: 8),
        const _MenuTile(icon: Icons.person_outline, label: 'Hồ sơ cá nhân'),
        const _MenuTile(
          icon: Icons.group_outlined,
          label: 'Mạng lưới chăm sóc',
        ),
        const _MenuTile(icon: Icons.notifications_outlined, label: 'Thông báo'),
        const _MenuTile(icon: Icons.accessibility_new, label: 'Trợ năng'),
        const _MenuTile(
          icon: Icons.privacy_tip_outlined,
          label: 'Quyền riêng tư',
        ),
        const _MenuTile(icon: Icons.help_outline, label: 'Trợ giúp'),
        const SizedBox(height: 16),
        const _LogoutButton(),
      ],
    );
  }
}

class _PatientTabScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  const _PatientTabScaffold({
    required this.title,
    required this.children,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: children,
        ),
      ),
    );
  }
}

class _SegmentHeader extends StatelessWidget {
  final List<String> labels;

  const _SegmentHeader({required this.labels});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: [
        for (final entry in labels.indexed)
          ButtonSegment(value: entry.$1, label: Text(entry.$2)),
      ],
      selected: const {0},
      onSelectionChanged: (_) {},
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final String chip;

  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.chip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.accessibility_new,
              color: colorScheme.primary,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                  const SizedBox(height: 4),
                  Text(meta, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Chip(label: Text(chip)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
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

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final _StatusTone tone;

  const _StatusBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _StatusTone.ready => (
          foreground: const Color(0xFF146C2E),
          background: const Color(0xFFC4EED0),
        ),
      _StatusTone.info => (
          foreground: Theme.of(context).colorScheme.primary,
          background: Theme.of(context).colorScheme.primaryContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.foreground, size: 32),
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
        ],
      ),
    );
  }
}

enum _StatusTone { ready, info }

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String primaryLabel;
  final String secondaryLabel;
  final IconData primaryIcon;
  final IconData secondaryIcon;

  const _ActionRow({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.primaryIcon,
    required this.secondaryIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {},
            icon: Icon(primaryIcon),
            label: Text(primaryLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () {},
            icon: Icon(secondaryIcon),
            label: Text(secondaryLabel),
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SessionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _LogoutButton extends StatefulWidget {
  const _LogoutButton();

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _submitting = false;

  Future<void> _logout() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
    });

    try {
      await provider.get<AuthRepository>().logout();
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthLoggedOut());
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _submitting ? null : _logout,
      icon: const Icon(Icons.logout),
      label: Text(_submitting ? 'Đang đăng xuất' : 'Đăng xuất'),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final Color color;

  const _TrendPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFC3C7CF)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final markerPaint = Paint()..color = color;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = [
      Offset(size.width * 0.08, size.height * 0.72),
      Offset(size.width * 0.24, size.height * 0.48),
      Offset(size.width * 0.40, size.height * 0.56),
      Offset(size.width * 0.58, size.height * 0.34),
      Offset(size.width * 0.76, size.height * 0.42),
      Offset(size.width * 0.92, size.height * 0.24),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 4, markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
