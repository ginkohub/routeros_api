import 'dart:io';
import 'package:routeros_api/routeros_api.dart';

/// This example demonstrates the most basic operations:
/// connecting, fetching identity, and listing interfaces.
void main() async {
  final client = RouterOSClient(
    host: Platform.environment['MIKROTIK_HOST'] ?? '192.168.88.1',
    user: Platform.environment['MIKROTIK_USER'] ?? 'admin',
    password: Platform.environment['MIKROTIK_PASS'] ?? 'password',
  );

  try {
    print('Connecting to RouterOS...');
    await client.connect();

    // 1. Get System Identity using talk()
    final identity = await client.talk(['/system/identity/print']);
    print('Router Identity: ${identity.first['name']}');

    // 2. Get Interfaces using the helper method
    print('\nAvailable Interfaces:');
    final interfaces = await client.getInterfaces();

    for (final interface in interfaces) {
      final name = interface['name'];
      final type = interface['type'];
      final status = (interface['running'] == 'true') ? 'UP' : 'DOWN';
      print(' - $name ($type) is $status');
    }
  } on RouterOSException catch (e) {
    print('RouterOS Error: ${e.message}');
  } catch (e) {
    print('Connection Error: $e');
  } finally {
    client.close();
    print('\nSession closed.');
  }
}
