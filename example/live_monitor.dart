import 'dart:io';
import 'package:routeros_api/routeros_api.dart';

/// This example showcases real-time data streaming using the [listen] method.
/// Perfect for building live dashboards or monitoring tools.
void main() async {
  final client = RouterOSClient(
    host: Platform.environment['MIKROTIK_HOST'] ?? '192.168.88.1',
    user: Platform.environment['MIKROTIK_USER'] ?? 'admin',
    password: Platform.environment['MIKROTIK_PASS'] ?? 'password',
  );

  try {
    print('Starting live traffic monitor on ISP1 (Press Ctrl+C to stop)...');

    final trafficStream = client.listen([
      '/interface/monitor-traffic',
      '=interface=ISP1',
    ]);

    print('TIME\t\tRX SPEED\tTX SPEED');
    print('----\t\t--------\t--------');

    int updates = 0;
    await for (final data in trafficStream) {
      final now = DateTime.now().toString().split(' ')[1].split('.')[0];
      final rx = _formatBps(data['rx-bits-per-second']);
      final tx = _formatBps(data['tx-bits-per-second']);

      print('$now\t$rx\t\t$tx');

      updates++;
      if (updates >= 10) {
        print('\nCaptured 10 updates. Stopping demo.');
        break;
      }
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}

String _formatBps(String? bits) {
  final value = double.tryParse(bits ?? '0') ?? 0;
  if (value > 1000000) return '${(value / 1000000).toStringAsFixed(1)} Mbps';
  if (value > 1000) return '${(value / 1000).toStringAsFixed(1)} Kbps';
  return '$value bps';
}
