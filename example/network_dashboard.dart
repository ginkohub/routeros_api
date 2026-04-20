import 'dart:io';
import 'package:routeros_api/routeros_api.dart';

/// This advanced example demonstrates data aggregation from multiple sources:
/// 1. Fetching DHCP leases to get device hostnames.
/// 2. Fetching Active Hotspot users.
/// 3. Filtering and correlating the results into a unified view.
void main() async {
  final client = RouterOSClient(
    host: Platform.environment['MIKROTIK_HOST'] ?? '192.168.88.1',
    user: Platform.environment['MIKROTIK_USER'] ?? 'admin',
    password: Platform.environment['MIKROTIK_PASS'] ?? 'password',
  );

  try {
    await client.connect();
    print('--- NETWORK INSIGHTS DASHBOARD ---\n');

    // Step A: Build a hostname map from DHCP Leases
    final leases = await client.getDHCPLeases();
    final ipToHost = {
      for (var l in leases)
        if (l['address'] != null)
          l['address']!: l['host-name'] ?? 'Generic Device'
    };

    // Step B: Fetch active hotspot users using execute() with a proplist
    final activeUsers = await client.execute(
      '/ip/hotspot/active/print',
      proplist: ['.id', 'user', 'address', 'uptime', 'bytes-out'],
    );

    print('TOP HOTSPOT CONSUMERS:');
    print(
        '${'USER'.padRight(15)}${'HOSTNAME'.padRight(25)}${'DOWNLOAD'.padRight(15)}UPTIME');
    print('=' * 70);

    // Sort by most bytes downloaded
    activeUsers.sort((a, b) {
      final bytesA = int.tryParse(a['bytes-out'] ?? '0') ?? 0;
      final bytesB = int.tryParse(b['bytes-out'] ?? '0') ?? 0;
      return bytesB.compareTo(bytesA);
    });

    for (final user in activeUsers.take(10)) {
      final username = (user['user'] ?? 'N/A').padRight(15);
      final hostname = (ipToHost[user['address']] ?? 'Unknown').padRight(25);
      final download = _formatBytes(user['bytes-out']).padRight(15);
      final uptime = user['uptime'] ?? '0s';

      print('$username$hostname$download$uptime');
    }
  } catch (e) {
    print('Error loading dashboard: $e');
  } finally {
    client.close();
  }
}

String _formatBytes(String? bytesStr) {
  final bytes = int.tryParse(bytesStr ?? '0') ?? 0;
  if (bytes > 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes > 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}
