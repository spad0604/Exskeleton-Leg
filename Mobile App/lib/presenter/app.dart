import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_state.dart';
import 'package:flutter_starter/data/sources/network/network.dart';
import 'package:flutter_starter/data/states/settings/settings_bloc.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/navigation/navigation.dart';
import 'package:flutter_starter/flavors.dart';
import 'package:flutter_starter/presenter/navigation/navigation_logger.dart';
import 'package:flutter_starter/services/firebase/fcm_service.dart';
import 'package:flutter_starter/services/ble/exo_ble_service.dart';
import 'package:flutter_starter/services/ble/exo_ble_protocol.dart';

class App extends StatefulWidget {
  static final _appRouter = provider.get<AppRouter>();
  static StreamSubscription<String>? _fcmSubscription;

  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription? _messageSubscription;
  StreamSubscription<FallAlert>? _fallSubscription;
  final _reportedFallAlerts = <String>{};

  @override
  void initState() {
    super.initState();
    _messageSubscription = FcmService.messageStream.listen((message) {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title']?.toString();
      final body = notification?.body ?? message.data['body']?.toString();
      if (title == null && body == null) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text([title, body].whereType<String>().join('\n')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
    _fallSubscription = ExoBleService.shared.fallAlerts.listen(_relayFallAlert);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _fallSubscription?.cancel();
    super.dispose();
  }

  Future<void> _relayFallAlert(FallAlert alert) async {
    final account = context.read<AuthBloc>().state.account;
    if (account == null || !account.roles.contains('patient')) return;
    final key = alert.alertId.isEmpty
        ? '${alert.deviceId}:${alert.timestampMs}:${alert.fallProbability}'
        : alert.alertId;
    if (!_reportedFallAlerts.add(key)) return;
    try {
      await provider.get<NetworkDataSource>().reportFall(
            patientId: account.id,
            alertId: alert.alertId,
            deviceId: alert.deviceId,
            probability: alert.fallProbability,
            message:
                'Phát hiện té ngã (độ tin cậy ${(alert.fallProbability * 100).round()}%). Thiết bị: ${alert.deviceId}.',
          );
      if (mounted) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Đã gửi cảnh báo đến người hướng dẫn.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Fall alert relay failed: $error\n$stackTrace');
      _reportedFallAlerts.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<SettingsBloc>().state.theme;

    return MultiBlocListener(
      listeners: [
        // Automatically navigate back to the login page when the user logged out
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previousState, state) =>
              previousState.loggedIn != state.loggedIn &&
              state.loggedIn == false,
          listener: (context, state) =>
              App._appRouter.replaceAll([const LoginRoute()]),
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previousState, state) =>
              previousState.loggedIn != state.loggedIn &&
              state.loggedIn == true,
          listener: (context, state) {
            final token = FcmService.token;
            if (token != null) {
              unawaited(
                provider
                    .get<NetworkDataSource>()
                    .registerFcmToken(token)
                    .catchError((error) {
                  if (kDebugMode) {
                    debugPrint('FCM token registration failed: $error');
                  }
                }),
              );
            }
            App._fcmSubscription?.cancel();
            App._fcmSubscription =
                FcmService.tokenStream.listen((refreshedToken) {
              unawaited(provider
                  .get<NetworkDataSource>()
                  .registerFcmToken(refreshedToken)
                  .catchError((error) {
                if (kDebugMode) {
                  debugPrint('FCM refreshed token registration failed: $error');
                }
              }));
            });
          },
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messengerKey,
        title: F.title,
        theme: appTheme.themeData,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: [
          ...context.localizationDelegates,
          // more delegates here
        ],
        routerConfig: App._appRouter.config(
          navigatorObservers: () => [
            if (kDebugMode) NavigationLogger(),
          ],
        ),
      ),
    );
  }
}
