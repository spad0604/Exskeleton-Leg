import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/repositories/auth_repository/auth_repository.dart';
import 'package:flutter_starter/data/entities/account.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_event.dart';
import 'package:flutter_starter/data/sources/network/network.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/languages/translation_keys.g.dart';
import 'package:flutter_starter/presenter/widgets/exo_kinematic_model.dart';
import 'package:flutter_starter/services/cloudinary/cloudinary_upload_service.dart';
import 'package:image_picker/image_picker.dart';

@RoutePage()
class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final patientId = context.read<AuthBloc>().state.account?.id;
    return _PlanListView(patientId: patientId!);
  }
}

class _PlanListView extends StatefulWidget {
  final String patientId;
  const _PlanListView({required this.patientId});

  @override
  State<_PlanListView> createState() => _PlanListViewState();
}

class _PlanListViewState extends State<_PlanListView> {
  int _selectedIndex = 0;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = provider.get<NetworkDataSource>().getPlanItems(
          widget.patientId,
          scope: _selectedIndex == 0 ? 'today' : 'all',
        );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _PatientTabScaffold(
              title: LocaleKeys.Patient_Tabs_Training.tr(),
              children: [
                if (snapshot.hasError)
                  FilledButton(
                      onPressed: () => setState(_load),
                      child: Text(LocaleKeys.Common_Retry.tr()))
                else
                  const Center(child: CircularProgressIndicator())
              ],
            );
          }
          final items = snapshot.data!;
          return _PatientTabScaffold(
            title: LocaleKeys.Patient_Tabs_Training.tr(),
            children: [
              _TrainingHero(pendingCount: items.length),
              const SizedBox(height: 16),
              _SegmentHeader(
                  selectedIndex: _selectedIndex,
                  onChanged: (index) => setState(() {
                        _selectedIndex = index;
                        _load();
                      }),
                  labels: [
                    LocaleKeys.Patient_Training_Today.tr(),
                    LocaleKeys.Patient_Training_All.tr(),
                  ]),
              const SizedBox(height: 16),
              for (final item in items) ...[
                _ExerciseCard(
                  title: _localizedExerciseName(item['exercise'] as Map),
                  subtitle: LocaleKeys.Common_SetsReps.tr(
                    args: [
                      '${(item['target'] as Map)['sets']}',
                      '${(item['target'] as Map)['repetitions_per_set']}',
                    ],
                  ),
                  meta: LocaleKeys.Common_ApproxMinutes.tr(
                    args: [
                      '${((item['estimated_duration_seconds'] as num) / 60).round()}',
                    ],
                  ),
                  chip: _selectedIndex == 0
                      ? LocaleKeys.Patient_Training_Today.tr()
                      : _localizedTrainingStatus('${item['status']}'),
                  icon: Icons.accessibility_new,
                  accent: _AccentTone.primary,
                  progress: 0,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ExerciseDetailPage(
                        exercise: item['exercise'] as Map,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      );
}

String _localizedExerciseName(Map exercise) {
  return _localizedExerciseCopy(exercise, 'name');
}

String _localizedExerciseCopy(Map exercise, String field) {
  final code = exercise['code'];
  final key = switch ('$code:$field') {
    'sit_to_stand:name' => LocaleKeys.Exercises_SitToStand_Name,
    'sit_to_stand:description' => LocaleKeys.Exercises_SitToStand_Description,
    'sit_to_stand:instructions' => LocaleKeys.Exercises_SitToStand_Instructions,
    'sit_to_stand:safety' => LocaleKeys.Exercises_SitToStand_Safety,
    'supported_knee_raise:name' => LocaleKeys.Exercises_SupportedKneeRaise_Name,
    'supported_knee_raise:description' =>
      LocaleKeys.Exercises_SupportedKneeRaise_Description,
    'supported_knee_raise:instructions' =>
      LocaleKeys.Exercises_SupportedKneeRaise_Instructions,
    'supported_knee_raise:safety' =>
      LocaleKeys.Exercises_SupportedKneeRaise_Safety,
    'seated_knee_extension:name' =>
      LocaleKeys.Exercises_SeatedKneeExtension_Name,
    'seated_knee_extension:description' =>
      LocaleKeys.Exercises_SeatedKneeExtension_Description,
    'seated_knee_extension:instructions' =>
      LocaleKeys.Exercises_SeatedKneeExtension_Instructions,
    'seated_knee_extension:safety' =>
      LocaleKeys.Exercises_SeatedKneeExtension_Safety,
    'heel_raises:name' => LocaleKeys.Exercises_HeelRaises_Name,
    'heel_raises:description' => LocaleKeys.Exercises_HeelRaises_Description,
    'heel_raises:instructions' => LocaleKeys.Exercises_HeelRaises_Instructions,
    'heel_raises:safety' => LocaleKeys.Exercises_HeelRaises_Safety,
    'straight_leg_raise:name' => LocaleKeys.Exercises_StraightLegRaise_Name,
    'straight_leg_raise:description' =>
      LocaleKeys.Exercises_StraightLegRaise_Description,
    'straight_leg_raise:instructions' =>
      LocaleKeys.Exercises_StraightLegRaise_Instructions,
    'straight_leg_raise:safety' => LocaleKeys.Exercises_StraightLegRaise_Safety,
    'heel_slides:name' => LocaleKeys.Exercises_HeelSlides_Name,
    'heel_slides:description' => LocaleKeys.Exercises_HeelSlides_Description,
    'heel_slides:instructions' => LocaleKeys.Exercises_HeelSlides_Instructions,
    'heel_slides:safety' => LocaleKeys.Exercises_HeelSlides_Safety,
    'quad_set:name' => LocaleKeys.Exercises_QuadSet_Name,
    'quad_set:description' => LocaleKeys.Exercises_QuadSet_Description,
    'quad_set:instructions' => LocaleKeys.Exercises_QuadSet_Instructions,
    'quad_set:safety' => LocaleKeys.Exercises_QuadSet_Safety,
    'supported_hip_extension:name' =>
      LocaleKeys.Exercises_SupportedHipExtension_Name,
    'supported_hip_extension:description' =>
      LocaleKeys.Exercises_SupportedHipExtension_Description,
    'supported_hip_extension:instructions' =>
      LocaleKeys.Exercises_SupportedHipExtension_Instructions,
    'supported_hip_extension:safety' =>
      LocaleKeys.Exercises_SupportedHipExtension_Safety,
    _ => null,
  };
  final fallbackField = field == 'name' ? 'name' : '${field}_key';
  return key == null ? '${exercise[fallbackField] ?? ''}' : key.tr();
}

String _localizedTrainingStatus(String status) {
  return switch (status) {
    'planned' => LocaleKeys.Patient_Training_Planned.tr(),
    'in_progress' => LocaleKeys.Patient_Training_InProgress.tr(),
    'completed' => LocaleKeys.Patient_Training_Completed.tr(),
    'skipped' => LocaleKeys.Patient_Training_Skipped.tr(),
    _ => status,
  };
}

@RoutePage()
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final patientId = context.read<AuthBloc>().state.account?.id;
    return _ProgressView(patientId: patientId!);
  }
}

class _ProgressView extends StatefulWidget {
  final String patientId;
  const _ProgressView({required this.patientId});
  @override
  State<_ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<_ProgressView> {
  int _selectedIndex = 0;
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = provider
      .get<NetworkDataSource>()
      .getProgressOverview(widget.patientId,
          period: _selectedIndex == 0 ? 'week' : 'month');
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _PatientTabScaffold(
                title: LocaleKeys.Patient_Tabs_Progress.tr(),
                children: [
                  if (snapshot.hasError)
                    FilledButton(
                        onPressed: () => setState(_load),
                        child: Text(LocaleKeys.Common_Retry.tr()))
                  else
                    const Center(child: CircularProgressIndicator())
                ]);
          }
          final data = snapshot.data!;
          return _PatientTabScaffold(
              title: LocaleKeys.Patient_Tabs_Progress.tr(),
              children: [
                _ProgressHero(
                  completed: (data['completed_count'] as num?)?.toInt() ?? 0,
                  planned: (data['planned_count'] as num?)?.toInt() ?? 0,
                ),
                const SizedBox(height: 16),
                _SegmentHeader(
                    selectedIndex: _selectedIndex,
                    onChanged: (index) => setState(() {
                          _selectedIndex = index;
                          _load();
                        }),
                    labels: [
                      LocaleKeys.Patient_Progress_Week.tr(),
                      LocaleKeys.Patient_Progress_Month.tr(),
                    ]),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: LocaleKeys.Patient_Progress_Completed.tr(),
                        value:
                            '${data['completed_count']} / ${data['planned_count']}',
                        assetPath: 'assets/images/ic_calendar.png',
                        accent: _AccentTone.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: LocaleKeys.Patient_Progress_TrainingTime.tr(),
                        value: LocaleKeys.Common_Minutes.tr(args: [
                          '${((data['active_seconds'] as num) / 60).round()}',
                        ]),
                        assetPath: 'assets/images/ic_clock.png',
                        accent: _AccentTone.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MetricCard(
                  label: LocaleKeys.Patient_Progress_CorrectMoves.tr(),
                  value:
                      '${((data['correctness_ratio'] as num) * 100).round()}%',
                  assetPath: 'assets/images/ic_heart_circle.png',
                  accent: _AccentTone.neutral,
                ),
                const SizedBox(height: 24),
                Text(
                    LocaleKeys.Patient_Progress_StreakDays.tr(
                      args: ['${data['streak_days']}'],
                    ),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                Text(LocaleKeys.Patient_Progress_RecentHistory.tr(),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...((data['recent_sessions'] as List<dynamic>? ?? const [])
                    .whereType<Map<String, dynamic>>()
                    .map((session) => _SessionTile(
                          title: '${session['status']}',
                          subtitle: '${session['started_at']}',
                          icon: session['status'] == 'completed'
                              ? Icons.done
                              : Icons.info_outline,
                        ))),
                if ((data['recent_sessions'] as List<dynamic>? ?? const [])
                    .isEmpty)
                  Text(LocaleKeys.Common_NotEnoughData.tr()),
              ]);
        },
      );
}

@RoutePage()
class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final patientId = context.read<AuthBloc>().state.account?.id;
    return _PatientApiView<List<Map<String, dynamic>>>(
      title: LocaleKeys.Patient_Tabs_Device.tr(),
      load: () => provider.get<NetworkDataSource>().getDevices(patientId!),
      builder: (items) {
        if (items.isEmpty) {
          return [
            const _DeviceModelCard(),
            const SizedBox(height: 16),
            _StatusBanner(
              assetPath: 'assets/images/ic_fill_setting.png',
              title: LocaleKeys.Patient_Device_NoDevice.tr(),
              message: LocaleKeys.Patient_Device_PairDeviceMessage.tr(),
              tone: _StatusTone.info,
            ),
          ];
        }
        final device = items.first;
        return [
          const _DeviceModelCard(),
          const SizedBox(height: 16),
          _DeviceHero(
            model: '${device['model'] ?? ''}',
            battery: (device['battery_percent'] as num?)?.toInt() ?? 0,
            ready: (device['readiness'] as Map?)?['state'] == 'ready',
          ),
          const SizedBox(height: 16),
          _StatusBanner(
            assetPath: 'assets/images/ic_fill_setting.png',
            title: (device['readiness'] as Map)['state'] == 'ready'
                ? LocaleKeys.Patient_Device_Ready.tr()
                : LocaleKeys.Patient_Device_NeedsCheck.tr(),
            message: LocaleKeys.Patient_Device_Battery.tr(args: [
              '${device['serial_number']}',
              '${device['battery_percent']}',
            ]),
            tone: _StatusTone.ready,
          ),
          const SizedBox(height: 16),
          _InfoTile(
            assetPath: 'assets/images/ic_fill_setting.png',
            title: device['model'] as String,
            subtitle: LocaleKeys.Patient_Device_Firmware.tr(args: [
              '${device['firmware_version']}',
            ]),
          ),
          _InfoTile(
            assetPath: 'assets/images/ic_heart_circle.png',
            title: LocaleKeys.Patient_Device_SensorsStable.tr(),
            subtitle: LocaleKeys.Patient_Device_SensorsStableSubtitle.tr(),
          ),
          _InfoTile(
            assetPath: 'assets/images/ic_clock.png',
            title: LocaleKeys.Patient_Device_CalibrationValid.tr(),
            subtitle: LocaleKeys.Patient_Device_CalibrationExpiry.tr(),
          ),
          const SizedBox(height: 16),
          _ActionRow(
            primaryLabel: LocaleKeys.Patient_Device_Calibrate.tr(),
            secondaryLabel: LocaleKeys.Patient_Device_Diagnostics.tr(),
            primaryIcon: Icons.straighten,
            secondaryIcon: Icons.fact_check_outlined,
          ),
        ];
      },
    );
  }
}

class _PatientApiView<T> extends StatefulWidget {
  final String title;
  final Future<T> Function() load;
  final List<Widget> Function(T data) builder;
  const _PatientApiView(
      {required this.title, required this.load, required this.builder});
  @override
  State<_PatientApiView<T>> createState() => _PatientApiViewState<T>();
}

class _PatientApiViewState<T> extends State<_PatientApiView<T>> {
  late Future<T> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _retry() => setState(() => _future = widget.load());
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
                appBar: AppBar(title: Text(widget.title)),
                body: const Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
                appBar: AppBar(title: Text(widget.title)),
                body: Center(
                    child: FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: Text(LocaleKeys.Common_Retry.tr()))));
          }
          return _PatientTabScaffold(
              title: widget.title,
              children: widget.builder(snapshot.data as T));
        },
      );
}

class PatientNotificationsPage extends StatefulWidget {
  const PatientNotificationsPage({super.key});

  @override
  State<PatientNotificationsPage> createState() =>
      _PatientNotificationsPageState();
}

class _PatientNotificationsPageState extends State<PatientNotificationsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = provider.get<NetworkDataSource>().getNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _PatientTabScaffold(
            title: LocaleKeys.Common_Notifications.tr(),
            children: [Center(child: CircularProgressIndicator())],
          );
        }
        if (snapshot.hasError) {
          return _PatientTabScaffold(
            title: LocaleKeys.Common_Notifications.tr(),
            children: [
              Center(child: Text(LocaleKeys.Patient_Home_LoadFailedTitle.tr())),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () => setState(_load),
                  child: Text(LocaleKeys.Common_Retry.tr())),
            ],
          );
        }
        final items =
            (snapshot.data ?? const <Map<String, dynamic>>[]).map((item) {
          final severity = item['severity'] as String? ?? 'info';
          return _NotificationItem(
            icon: severity == 'warning'
                ? Icons.warning_amber_rounded
                : Icons.notifications,
            title: item['title'] as String? ?? '',
            body: item['title'] as String? ?? '',
            time: item['occurred_at'] as String? ?? '',
            tone: severity == 'critical'
                ? _AccentTone.tertiary
                : _AccentTone.primary,
            unread: item['resolved_at'] == null,
          );
        }).toList();
        return _PatientTabScaffold(
          title: LocaleKeys.Common_Notifications.tr(),
          children: [
            _NotificationSummary(
                unreadCount: items.where((e) => e.unread).length),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Center(child: Text(LocaleKeys.Patient_Device_NoDevice.tr()))
            else ...[
              _SegmentHeader(labels: [
                LocaleKeys.Patient_Notifications_All.tr(),
                LocaleKeys.Patient_Notifications_Unread.tr()
              ]),
              const SizedBox(height: 16),
              for (final item in items) ...[
                _NotificationBlock(item: item),
                const SizedBox(height: 12)
              ],
            ],
          ],
        );
      },
    );
  }
}

@RoutePage()
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

void _openProfileInfo(BuildContext context, String title, String subtitle) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _ProfileInfoPage(title: title, subtitle: subtitle),
    ),
  );
}

class _ProfileInfoPage extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ProfileInfoPage({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.secondaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primary,
                  child: Icon(Icons.person_outline,
                      color: scheme.onPrimary, size: 30),
                ),
                const SizedBox(height: 18),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: _TintIcon(
                  icon: Icons.info_outline,
                  background: scheme.tertiaryContainer,
                  foreground: scheme.tertiary,
                  size: 48,
                ),
                title: Text(title),
                subtitle: Text(subtitle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openAccountDetails(BuildContext context, Account? account) {
  if (account == null) return;
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => _AccountDetailsPage(account: account),
  ));
}

class _AccountDetailsPage extends StatelessWidget {
  final Account account;
  const _AccountDetailsPage({required this.account});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar:
          AppBar(title: Text(LocaleKeys.Patient_Profile_PersonalProfile.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(28)),
            child: Row(children: [
              CircleAvatar(
                  radius: 34,
                  backgroundColor: scheme.primary,
                  child: Text(
                      account.displayName.characters.first.toUpperCase(),
                      style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800))),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(account.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(account.email ?? '—', overflow: TextOverflow.ellipsis),
                  ])),
            ]),
          ),
          const SizedBox(height: 16),
          _AccountField(
              icon: Icons.badge_outlined,
              label: LocaleKeys.Patient_Profile_Role.tr(),
              value: account.roles.join(', '),
              accent: _AccentTone.primary),
          _AccountField(
              icon: Icons.email_outlined,
              label: LocaleKeys.Common_Email.tr(),
              value: account.email ?? '—',
              accent: _AccentTone.secondary),
          _AccountField(
              icon: Icons.language_outlined,
              label: LocaleKeys.Common_Locale.tr(),
              value: account.locale ?? '—',
              accent: _AccentTone.tertiary),
          _AccountField(
              icon: Icons.schedule_outlined,
              label: LocaleKeys.Common_Timezone.tr(),
              value: account.timezone ?? '—',
              accent: _AccentTone.neutral),
          _AccountField(
              icon: Icons.verified_user_outlined,
              label: LocaleKeys.Patient_Profile_Status.tr(),
              value: LocaleKeys.Patient_Profile_Active.tr(),
              accent: _AccentTone.secondary),
        ],
      ),
    );
  }
}

class _AccountField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final _AccentTone accent;
  const _AccountField(
      {required this.icon,
      required this.label,
      required this.value,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    final colors = _accentColors(Theme.of(context).colorScheme, accent);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: ListTile(
        leading: _TintIcon(
            icon: icon,
            background: colors.background,
            foreground: colors.foreground,
            size: 48),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}

class _ProfilePageState extends State<ProfilePage> {
  final _picker = ImagePicker();
  final _cloudinary = CloudinaryUploadService();
  String? _avatarUrl;
  bool _uploading = false;

  Future<void> _pickAndUploadAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 86,
    );
    if (image == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await _cloudinary.uploadAvatar(image);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.Patient_Profile_UploadSuccess.tr())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.Patient_Profile_UploadFailed.tr()),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthBloc>().state.account;
    final displayName =
        account?.displayName ?? LocaleKeys.Patient_Profile_FallbackName.tr();

    return _PatientTabScaffold(
      title: LocaleKeys.Patient_Tabs_Profile.tr(),
      children: [
        _ProfileHeader(
          displayName: displayName,
          email: account?.email ?? LocaleKeys.Patient_Profile_NoEmail.tr(),
          avatarUrl: _avatarUrl,
          uploading: _uploading,
          onUpload: _pickAndUploadAvatar,
        ),
        const SizedBox(height: 16),
        _ProfileInfoGrid(
          items: [
            _ProfileInfoItem(
              label: LocaleKeys.Patient_Profile_Role.tr(),
              value: account?.roles.join(', ') ??
                  LocaleKeys.Patient_Profile_PatientAccount.tr(),
              icon: Icons.badge_outlined,
              accent: _AccentTone.primary,
            ),
            _ProfileInfoItem(
              label: LocaleKeys.Patient_Profile_Status.tr(),
              value: LocaleKeys.Patient_Profile_Active.tr(),
              icon: Icons.verified_user_outlined,
              accent: _AccentTone.secondary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ProfileSection(
          title: LocaleKeys.Patient_Profile_AccountSection.tr(),
          children: [
            _MenuTile(
              assetPath: 'assets/images/ic_indentity.png',
              label: LocaleKeys.Patient_Profile_PersonalProfile.tr(),
              subtitle: LocaleKeys.Patient_Profile_PersonalProfileSubtitle.tr(),
              onTap: () => _openAccountDetails(context, account),
            ),
            _MenuTile(
              assetPath: 'assets/images/ic_phone.png',
              label: LocaleKeys.Patient_Profile_CareNetwork.tr(),
              subtitle: LocaleKeys.Patient_Profile_CareNetworkSubtitle.tr(),
              onTap: () => _openProfileInfo(
                  context,
                  LocaleKeys.Patient_Profile_CareNetwork.tr(),
                  LocaleKeys.Patient_Profile_CareNetworkSubtitle.tr()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ProfileSection(
          title: LocaleKeys.Patient_Profile_SettingsSection.tr(),
          children: [
            _MenuTile(
              assetPath: 'assets/images/ic_fill_bell.png',
              label: LocaleKeys.Patient_Profile_Notifications.tr(),
              subtitle: LocaleKeys.Patient_Profile_NotificationsSubtitle.tr(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PatientNotificationsPage(),
                ),
              ),
            ),
            const _LanguageTile(),
            _MenuTile(
              assetPath: 'assets/images/ic_heart_circle.png',
              label: LocaleKeys.Patient_Profile_Accessibility.tr(),
              subtitle: LocaleKeys.Patient_Profile_AccessibilitySubtitle.tr(),
              onTap: () => _openProfileInfo(
                  context,
                  LocaleKeys.Patient_Profile_Accessibility.tr(),
                  LocaleKeys.Patient_Profile_AccessibilitySubtitle.tr()),
            ),
            _MenuTile(
              assetPath: 'assets/images/ic_fill_indentity.png',
              label: LocaleKeys.Patient_Profile_Privacy.tr(),
              subtitle: LocaleKeys.Patient_Profile_PrivacySubtitle.tr(),
              onTap: () => _openProfileInfo(
                  context,
                  LocaleKeys.Patient_Profile_Privacy.tr(),
                  LocaleKeys.Patient_Profile_PrivacySubtitle.tr()),
            ),
            _MenuTile(
              assetPath: 'assets/images/ic_fill_help.png',
              label: LocaleKeys.Patient_Profile_Help.tr(),
              subtitle: LocaleKeys.Patient_Profile_HelpSubtitle.tr(),
              onTap: () => _openProfileInfo(
                  context,
                  LocaleKeys.Patient_Profile_Help.tr(),
                  LocaleKeys.Patient_Profile_HelpSubtitle.tr()),
            ),
          ],
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
  const _PatientTabScaffold({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
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
  final int pendingCount;

  const _TrainingHero({required this.pendingCount});

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
                  LocaleKeys.Patient_Training_PendingTitle.tr(
                    args: ['$pendingCount'],
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  LocaleKeys.Patient_Training_PendingSubtitle.tr(),
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
  final int completed;
  final int planned;

  const _ProgressHero({required this.completed, required this.planned});

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
                  LocaleKeys.Patient_Progress_HeroTitle.tr(
                    args: ['$completed', '$planned'],
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  LocaleKeys.Patient_Progress_HeroSubtitle.tr(),
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
  final String model;
  final int battery;
  final bool ready;

  const _DeviceHero({
    required this.model,
    required this.battery,
    required this.ready,
  });

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
                  model,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  LocaleKeys.Patient_Device_HeroSubtitle.tr(
                    args: [
                      '$battery',
                      ready
                          ? LocaleKeys.Patient_Device_Ready.tr()
                          : LocaleKeys.Patient_Device_NeedsCheck.tr(),
                    ],
                  ),
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

class _DeviceModelCard extends StatelessWidget {
  const _DeviceModelCard();

  bool get _supports3dView =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.16)),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerLowest,
            colorScheme.secondaryContainer.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                _TintIcon(
                  icon: Icons.view_in_ar_outlined,
                  background: colorScheme.primary,
                  foreground: colorScheme.onPrimary,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    LocaleKeys.Patient_Device_ModelTitle.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Icon(Icons.touch_app_outlined,
                    color: colorScheme.primary.withValues(alpha: 0.8)),
              ],
            ),
          ),
          SizedBox(
            height: 380,
            width: double.infinity,
            child: _supports3dView
                ? Semantics(
                    label: LocaleKeys.Patient_Device_PairedModel.tr(),
                    child: const ExoKinematicModel(),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        LocaleKeys.Patient_Device_ModelUnavailable.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
            child: Text(
              LocaleKeys.Patient_Device_ModelSubtitle.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.78),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentHeader extends StatefulWidget {
  final List<String> labels;
  final int? selectedIndex;
  final ValueChanged<int>? onChanged;

  const _SegmentHeader(
      {required this.labels, this.selectedIndex, this.onChanged});

  @override
  State<_SegmentHeader> createState() => _SegmentHeaderState();
}

class _SegmentHeaderState extends State<_SegmentHeader> {
  int _selectedIndex = 0;

  int get selectedIndex => widget.selectedIndex ?? _selectedIndex;

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
                left: selectedIndex * itemWidth + 4,
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
                          widget.onChanged?.call(entry.$1);
                          if (widget.onChanged == null) {
                            setState(() => _selectedIndex = entry.$1);
                          }
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: selectedIndex == entry.$1
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                    ) ??
                                TextStyle(
                                  color: selectedIndex == entry.$1
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
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.chip,
    required this.icon,
    required this.accent,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _accentColors(colorScheme, accent);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
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
                  Icon(Icons.chevron_right, color: colors.foreground),
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
      ),
    );
  }
}

class _ExerciseDetailPage extends StatelessWidget {
  final Map exercise;

  const _ExerciseDetailPage({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _localizedExerciseName(exercise);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                _TintIcon(
                  icon: Icons.accessibility_new,
                  background: colorScheme.primary,
                  foreground: colorScheme.onPrimary,
                  size: 58,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ExerciseDetailSection(
            icon: Icons.info_outline,
            title: LocaleKeys.Common_Description.tr(),
            content: _localizedExerciseCopy(exercise, 'description'),
            color: colorScheme.primary,
          ),
          _ExerciseDetailSection(
            icon: Icons.format_list_numbered,
            title: LocaleKeys.Common_Instructions.tr(),
            content: _localizedExerciseCopy(exercise, 'instructions'),
            color: colorScheme.tertiary,
          ),
          _ExerciseDetailSection(
            icon: Icons.health_and_safety_outlined,
            title: LocaleKeys.Common_Safety.tr(),
            content: _localizedExerciseCopy(exercise, 'safety'),
            color: colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(LocaleKeys.Exercises_Disclaimer.tr(),
              style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ExerciseDetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _ExerciseDetailSection({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium)
          ]),
          const SizedBox(height: 10),
          Text(content),
        ],
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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
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

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onUpload;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.uploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: colorScheme.primary,
                foregroundImage:
                    avatarUrl == null ? null : NetworkImage(avatarUrl!),
                child: avatarUrl == null
                    ? Text(
                        displayName.characters.first.toUpperCase(),
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Tooltip(
                  message: LocaleKeys.Patient_Profile_UploadPhoto.tr(),
                  child: IconButton.filled(
                    onPressed: uploading ? null : onUpload,
                    icon: uploading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.photo_camera_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: uploading ? null : onUpload,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(LocaleKeys.Patient_Profile_UploadPhoto.tr()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoGrid extends StatelessWidget {
  final List<_ProfileInfoItem> items;

  const _ProfileInfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in items.indexed) ...[
          if (entry.$1 > 0) const SizedBox(width: 12),
          Expanded(child: _ProfileInfoCard(item: entry.$2)),
        ],
      ],
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final _ProfileInfoItem item;

  const _ProfileInfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _accentColors(colorScheme, item.accent);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: colors.foreground),
          const SizedBox(height: 10),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoItem {
  final String label;
  final String value;
  final IconData icon;
  final _AccentTone accent;

  const _ProfileInfoItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...children,
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String assetPath;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.assetPath,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
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
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _NotificationSummary extends StatelessWidget {
  final int unreadCount;

  const _NotificationSummary({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _TintIcon(
            icon: Icons.notifications_active_outlined,
            background: colorScheme.secondary,
            foreground: colorScheme.onSecondary,
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.Patient_Notifications_SummaryTitle.tr(
                    args: ['$unreadCount'],
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  LocaleKeys.Patient_Notifications_SummaryBody.tr(),
                  style: TextStyle(color: colorScheme.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBlock extends StatelessWidget {
  final _NotificationItem item;

  const _NotificationBlock({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _accentColors(colorScheme, item.tone);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: item.unread
              ? colors.foreground.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TintIcon(
              icon: item.icon,
              background: colors.background,
              foreground: colors.foreground,
              size: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      if (item.unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.body,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MetaPill(
                        icon: Icons.schedule,
                        label: item.time,
                        background: colorScheme.surfaceContainerLow,
                        foreground: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final _AccentTone tone;
  final bool unread;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.tone,
    required this.unread,
  });
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentLanguage = context.locale.languageCode == 'vi'
        ? LocaleKeys.Common_Vietnamese.tr()
        : LocaleKeys.Common_English.tr();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLanguagePicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              _TintIcon(
                icon: Icons.translate,
                background: colorScheme.tertiaryContainer,
                foreground: colorScheme.tertiary,
                size: 54,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.Common_Language.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      currentLanguage,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  LocaleKeys.Patient_Profile_ChooseLanguage.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              _LanguageOption(
                title: LocaleKeys.Common_English.tr(),
                subtitle: LocaleKeys.Patient_Profile_EnglishSubtitle.tr(),
                selected: context.locale.languageCode == 'en',
                color: colorScheme.primary,
                onTap: () async => _setLocale(sheetContext, const Locale('en')),
              ),
              const SizedBox(height: 10),
              _LanguageOption(
                title: LocaleKeys.Common_Vietnamese.tr(),
                subtitle: LocaleKeys.Patient_Profile_VietnameseSubtitle.tr(),
                selected: context.locale.languageCode == 'vi',
                color: colorScheme.tertiary,
                onTap: () async => _setLocale(sheetContext, const Locale('vi')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setLocale(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : colorScheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(Icons.language, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? color : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
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
            onPressed: () => _showActionDialog(context, primaryLabel),
            icon: Icon(primaryIcon),
            label: Text(primaryLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _showActionDialog(context, secondaryLabel),
            icon: Icon(secondaryIcon),
            label: Text(secondaryLabel),
          ),
        ),
      ],
    );
  }

  void _showActionDialog(BuildContext context, String action) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action),
        content: Text(LocaleKeys.Patient_Device_HeroSubtitle.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LocaleKeys.Common_Ok.tr())),
        ],
      ),
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
        label: Text(
          _submitting
              ? LocaleKeys.Common_LoggingOut.tr()
              : LocaleKeys.Common_Logout.tr(),
        ),
      ),
    );
  }
}
