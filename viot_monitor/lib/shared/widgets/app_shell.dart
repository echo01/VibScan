import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/app_providers.dart';
import '../../features/config/presentation/config_device_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/devices/presentation/device_list_page.dart';
import '../../features/mqtt/presentation/mqtt_page.dart';
import '../../features/wifi/presentation/select_wifi_page.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navigationIndexProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appName)),
      body: Stack(
        children: [
          switch (index) {
            0 => const SelectWifiPage(),
            1 => const DeviceListPage(),
            2 => const DashboardPage(),
            3 => const MqttPage(),
            _ => const ConfigDevicePage(),
          },
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            ref.read(navigationIndexProvider.notifier).state = value,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wifi_rounded),
            label: AppStrings.wifi,
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_rounded),
            label: AppStrings.analyze,
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_customize_rounded),
            label: AppStrings.dashboard,
          ),
          NavigationDestination(icon: Icon(Icons.hub_rounded), label: 'MQTT'),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: AppStrings.config,
          ),
        ],
      ),
    );
  }
}
