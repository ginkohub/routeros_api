import 'dart:io';
import 'package:routeros_api/routeros_api.dart';

void main() async {
  final client = RouterOSClient(
    host: Platform.environment['MIKROTIK_HOST'] ?? '192.168.88.1',
    user: Platform.environment['MIKROTIK_USER'] ?? 'admin',
    password: Platform.environment['MIKROTIK_PASS'] ?? 'password',
  );

  try {
    await client.connect();
    print('--- NETWORK INSIGHTS DASHBOARD ---\n');

    // Fetch DHCP Leases using execute
    final leases = await client.execute('/ip/dhcp-server/lease/print');
    final ipToHost = {
      for (var l in leases)
        if (l['address'] != null)
          l['address']!: l['host-name'] ?? 'Generic Device'
    };

    // Fetch active hotspot users
    final activeUsers = await client.execute(
      '/ip/hotspot/active/print',
      proplist: ['.id', 'user', 'address', 'uptime', 'bytes-out'],
    );

    print('TOP HOTSPOT CONSUMERS:');
    print(
        '${'USER'.padRight(15)}${'HOSTNAME'.padRight(25)}${'DOWNLOAD'.padRight(15)}UPTIME');
    print('=' * 70);

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

    // Fetch System Resource
    print('\nSYSTEM INFO:');
    final resources = await client.execute('/system/resource/print');
    if (resources.isNotEmpty) {
      final r = resources.first;
      print('Board: ${r['board-name']} (${r['version']})');
      print('CPU: ${r['cpu']} @ ${r['cpu-frequency']}MHz');
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
