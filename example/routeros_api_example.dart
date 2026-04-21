import 'dart:io';
import 'package:routeros_api/routeros_api.dart';

void main() async {
  final client = RouterOSClient(
    host: Platform.environment['MIKROTIK_HOST'] ?? '192.168.88.1',
    user: Platform.environment['MIKROTIK_USER'] ?? 'admin',
    password: Platform.environment['MIKROTIK_PASS'] ?? 'password',
  );

  try {
    print('Connecting to RouterOS...');
    await client.connect();

    // Get system identity
    final identity = await client.execute('/system/identity/print');
    print('Router Identity: ${identity.first['name']}');

    // List interfaces using execute
    print('\nAvailable Interfaces:');
    final interfaces = await client.execute('/interface/print');

    for (final interface in interfaces) {
      final name = interface['name'];
      final type = interface['type'];
      final status = (interface['running'] == 'true') ? 'UP' : 'DOWN';
      print(' - $name ($type) is $status');
    }

    print('\nHotspot Users Active:');
    // Using execute with countOnly: true (supports ROS 6.43+)
    final activeResults = await client
        .execute('/ip/hotspot/active/print', flags: ["=count-only="]);

    // Some versions of RouterOS return 'count', others return 'ret'
    final total =
        activeResults.first['count'] ?? activeResults.first['ret'] ?? '0';
    print('Execute: $total');

    // Or using talk with the raw parameter
    final rawCount =
        await client.talk(['/ip/hotspot/active/print', '=count-only=']);
    print('Talk: ${rawCount.first["ret"]}');
  } on RouterOSException catch (e) {
    print('RouterOS Error: ${e.message}');
  } catch (e) {
    print('Connection Error: $e');
  } finally {
    client.close();
    print('\nSession closed.');
  }
}
