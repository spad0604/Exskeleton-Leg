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
      children: [
        const _TrainingHero(),
        const SizedBox(height: 16),
        const _SegmentHeader(labels: ['Hôm nay', 'Tất cả']),
        const SizedBox(height: 16),
        _ExerciseCard(
          title: 'Đứng lên và ngồi xuống',
          subtitle: '2 hiệp x 8 lần',
          meta: 'Khoảng 10 phút',
          chip: 'Hôm nay',
          icon: Icons.accessibility_new,
          accent: _AccentTone.primary,
          progress: 0.72,
        ),
        const SizedBox(height: 12),
        _ExerciseCard(
          title: 'Nâng gối có hỗ trợ',
          subtitle: '3 hiệp x 6 lần mỗi bên',
          meta: 'Hỗ trợ thấp',
          chip: 'Cần thiết bị',
          icon: Icons.directions_walk,
          accent: _AccentTone.secondary,
          progress: 0.45,
        ),
        const SizedBox(height: 12),
        _ExerciseCard(
          title: 'Duỗi hông chậm',
          subtitle: 'Giữ 5 giây mỗi lần',
          meta: 'Tập kiểm soát',
          chip: 'Tất cả',
          icon: Icons.self_improvement,
          accent: _AccentTone.tertiary,
          progress: 0.28,
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
        const _ProgressHero(),
        const SizedBox(height: 16),
        const _SegmentHeader(labels: ['Tuần', 'Tháng']),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Hoàn thành',
                value: '6 / 8',
                assetPath: 'assets/images/ic_calendar.png',
                accent: _AccentTone.primary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Thời gian',
                value: '54 phút',
                assetPath: 'assets/images/ic_clock.png',
                accent: _AccentTone.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _MetricCard(
          label: 'Động tác đạt',
          value: '81%',
          assetPath: 'assets/images/ic_heart_circle.png',
          accent: _AccentTone.neutral,
        ),
        const SizedBox(height: 24),
        Text('Xu hướng', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          height: 168,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: CustomPaint(
            painter: _TrendPainter(colorScheme.secondary),
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
        _DeviceHero(),
        SizedBox(height: 16),
        _StatusBanner(
          assetPath: 'assets/images/ic_fill_setting.png',
          title: 'Thiết bị đã sẵn sàng',
          message: 'EXO-2026-000123 - Pin 78%',
          tone: _StatusTone.ready,
        ),
        SizedBox(height: 16),
        _InfoTile(
          assetPath: 'assets/images/ic_fill_setting.png',
          title: 'Exoskeleton Leg v1',
          subtitle: 'Firmware 1.2.0 - Kết nối 08:00',
        ),
        _InfoTile(
          assetPath: 'assets/images/ic_heart_circle.png',
          title: 'Cảm biến hoạt động ổn định',
          subtitle: 'Hông trái/phải, gối trái/phải đều sẵn sàng',
        ),
        _InfoTile(
          assetPath: 'assets/images/ic_clock.png',
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
          assetPath: 'assets/images/ic_account.png',
          title: account?.displayName ?? 'Người tập',
          subtitle: 'Tài khoản patient',
        ),
        const SizedBox(height: 8),
        const _MenuTile(
          assetPath: 'assets/images/ic_indentity.png',
          label: 'Hồ sơ cá nhân',
        ),
        const _MenuTile(
          assetPath: 'assets/images/ic_phone.png',
          label: 'Mạng lưới chăm sóc',
        ),
        const _MenuTile(
          assetPath: 'assets/images/ic_fill_bell.png',
          label: 'Thông báo',
        ),
        const _MenuTile(
          assetPath: 'assets/images/ic_heart_circle.png',
          label: 'Trợ năng',
        ),
        const _MenuTile(
          assetPath: 'assets/images/ic_fill_indentity.png',
          label: 'Quyền riêng tư',
        ),
        const _MenuTile(
          assetPath: 'assets/images/ic_fill_help.png',
          label: 'Trợ giúp',
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.primary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: children,
        ),
      ),
    );
  }
}

class _TrainingHero extends StatelessWidget {
  const _TrainingHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          _TintIcon(
            icon: Icons.fitness_center,
            background: colorScheme.primary,
            foreground: colorScheme.onPrimary,
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3 bài đang chờ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ưu tiên bài hôm nay và kiểm tra thiết bị trước khi tập.',
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHero extends StatelessWidget {
  const _ProgressHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          _TintIcon(
            icon: Icons.trending_up,
            background: colorScheme.tertiary,
            foreground: colorScheme.onTertiary,
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tuần này ổn định hơn',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hoàn thành tăng 12% so với tuần trước.',
                  style: TextStyle(color: colorScheme.onTertiaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceHero extends StatelessWidget {
  const _DeviceHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _AssetTintIcon(
            assetPath: 'assets/images/ic_fill_setting.png',
            background: colorScheme.primary,
            foreground: colorScheme.onPrimary,
            size: 64,
            iconSize: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exoskeleton đang kết nối',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Pin 78% - cảm biến sẵn sàng',
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentHeader extends StatefulWidget {
  final List<String> labels;

  const _SegmentHeader({required this.labels});

  @override
  State<_SegmentHeader> createState() => _SegmentHeaderState();
}

class _SegmentHeaderState extends State<_SegmentHeader> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width / widget.labels.length;

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _selectedIndex * itemWidth + 4,
                top: 5,
                bottom: 5,
                width: itemWidth - 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final entry in widget.labels.indexed)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _selectedIndex = entry.$1;
                          });
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: _selectedIndex == entry.$1
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                    ) ??
                                TextStyle(
                                  color: _selectedIndex == entry.$1
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                            child: Text(entry.$2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final String chip;
  final IconData icon;
  final _AccentTone accent;
  final double progress;

  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.chip,
    required this.icon,
    required this.accent,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _accentColors(colorScheme, accent);

    return Card(
      color: colorScheme.surface,
      surfaceTintColor: colors.foreground,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TintIcon(
                  icon: icon,
                  background: colors.background,
                  foreground: colors.foreground,
                  size: 54,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Xem bài tập',
                  onPressed: () {},
                  icon: Icon(Icons.chevron_right, color: colors.foreground),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress,
                color: colors.foreground,
                backgroundColor: colors.background,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MetaPill(
                  icon: Icons.schedule,
                  label: meta,
                  background: colorScheme.surfaceContainerLow,
                  foreground: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                _MetaPill(
                  icon: Icons.flag_outlined,
                  label: chip,
                  background: colors.background,
                  foreground: colors.foreground,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TintIcon extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  const _TintIcon({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: foreground, size: size * 0.54),
    );
  }
}

class _AssetTintIcon extends StatelessWidget {
  final String assetPath;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;

  const _AssetTintIcon({
    required this.assetPath,
    required this.background,
    required this.foreground,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Center(
        child: ImageIcon(
          AssetImage(assetPath),
          color: foreground,
          size: iconSize,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AccentTone { primary, secondary, tertiary, neutral }

({Color background, Color foreground}) _accentColors(
  ColorScheme colorScheme,
  _AccentTone tone,
) {
  return switch (tone) {
    _AccentTone.primary => (
        background: colorScheme.primaryContainer,
        foreground: colorScheme.primary,
      ),
    _AccentTone.secondary => (
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.secondary,
      ),
    _AccentTone.tertiary => (
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.tertiary,
      ),
    _AccentTone.neutral => (
        background: Colors.white,
        foreground: colorScheme.primary,
      ),
  };
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String assetPath;
  final _AccentTone accent;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.assetPath,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _accentColors(colorScheme, accent);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(24),
        border: accent == _AccentTone.neutral
            ? Border.all(color: colorScheme.outlineVariant)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssetTintIcon(
            assetPath: assetPath,
            background: colors.foreground.withValues(alpha: 0.12),
            foreground: colors.foreground,
            size: 42,
            iconSize: 23,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: colors.foreground),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String assetPath;
  final String title;
  final String message;
  final _StatusTone tone;

  const _StatusBanner({
    required this.assetPath,
    required this.title,
    required this.message,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _StatusTone.ready => (
          foreground: Theme.of(context).colorScheme.secondary,
          background: Theme.of(context).colorScheme.secondaryContainer,
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
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _AssetTintIcon(
            assetPath: assetPath,
            background: colors.foreground.withValues(alpha: 0.14),
            foreground: colors.foreground,
            size: 56,
            iconSize: 30,
          ),
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
  final String assetPath;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.assetPath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.primary,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        leading: _AssetTintIcon(
          assetPath: assetPath,
          background: colorScheme.primaryContainer,
          foreground: colorScheme.primary,
          size: 56,
          iconSize: 31,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String assetPath;
  final String label;

  const _MenuTile({required this.assetPath, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: Colors.white,
      elevation: 1,
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: _AssetTintIcon(
          assetPath: assetPath,
          background: colorScheme.secondaryContainer,
          foreground: colorScheme.secondary,
          size: 54,
          iconSize: 29,
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: colorScheme.onPrimaryContainer),
      ),
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _submitting ? null : _logout,
        icon: const Icon(Icons.logout),
        label: Text(_submitting ? 'Đang đăng xuất' : 'Đăng xuất'),
      ),
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
