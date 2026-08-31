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

class App extends StatelessWidget {
  static final _appRouter = provider.get<AppRouter>();

  const App({super.key});

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
              _appRouter.replaceAll([const LoginRoute()]),
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
          },
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: F.title,
        theme: appTheme.themeData,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: [
          ...context.localizationDelegates,
          // more delegates here
        ],
        routerConfig: _appRouter.config(
          navigatorObservers: () => [
            if (kDebugMode) NavigationLogger(),
          ],
        ),
      ),
    );
  }
}
