import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/presenter/navigation/navigation.dart';

@RoutePage()
class PatientShellPage extends StatelessWidget {
  const PatientShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [
        HomeRoute(),
        TrainingRoute(),
        ProgressRoute(),
        DeviceRoute(),
        ProfileRoute(),
      ],
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);

        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tabsRouter.activeIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: tabsRouter.setActiveIndex,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Hôm nay',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Bài tập',
              ),
              NavigationDestination(
                icon: Icon(Icons.monitoring_outlined),
                selectedIcon: Icon(Icons.monitoring),
                label: 'Tiến độ',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_remote_outlined),
                selectedIcon: Icon(Icons.settings_remote),
                label: 'Thiết bị',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Cá nhân',
              ),
            ],
          ),
        );
      },
    );
  }
}
