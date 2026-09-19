import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/sources/network/network.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/pages/patient/patient_placeholders.dart';
import 'package:flutter_starter/presenter/pages/patient/motion_builder.dart';

@RoutePage()
class CaregiverShellPage extends StatefulWidget {
  const CaregiverShellPage({super.key});

  @override
  State<CaregiverShellPage> createState() => _CaregiverShellPageState();
}

class _CaregiverShellPageState extends State<CaregiverShellPage> {
  late Future<List<Map<String, dynamic>>> _relationships;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _relationships = provider.get<NetworkDataSource>().getRelationships();
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthBloc>().state.account;
    return Scaffold(
      appBar: AppBar(title: const Text('Giám sát người tập')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Xin chào, ${account?.displayName ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Liên kết với người tập để theo dõi tiến độ và nhận cảnh báo té ngã.'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const CareNetworkPage())),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Quản lý người tập'),
          ),
          const SizedBox(height: 28),
          Text('Người tập đã liên kết',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _relationships,
            builder: (context, snapshot) {
              final links = (snapshot.data ?? const <Map<String, dynamic>>[])
                  .where((link) => link['status'] == 'active')
                  .toList();
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (links.isEmpty) {
                return const _CareSurface(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                        'Chưa có người tập active. Hãy liên kết bằng email trước.'),
                  ),
                );
              }
              return Column(
                children: links.map((link) {
                  final patientId = link['patient_id']?.toString();
                  return _CareSurface(
                    child: ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.accessibility_new)),
                      title:
                          Text(link['patient_name']?.toString() ?? 'Người tập'),
                      subtitle: Text(link['patient_email']?.toString() ?? ''),
                      trailing: patientId == null
                          ? null
                          : FilledButton.tonal(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => MotionRoutineLibraryPage(
                                      patientId: patientId),
                                ),
                              ),
                              child: const Text('Tạo bài'),
                            ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CareSurface extends StatelessWidget {
  final Widget child;
  const _CareSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
