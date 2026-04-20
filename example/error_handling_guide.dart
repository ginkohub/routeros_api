import 'dart:async';
import 'dart:io';
import 'package:routeros_api/routeros_api.dart';

/// This example demonstrates how to handle various failure scenarios:
/// 1. Connection timeouts.
/// 2. Authentication failures.
/// 3. Invalid commands (Traps).
/// 4. Operation timeouts.
void main() async {
  final host = Platform.environment['MIKROTIK_HOST'] ?? '192.168.88.1';
  final user = Platform.environment['MIKROTIK_USER'] ?? 'admin';
  final pass = Platform.environment['MIKROTIK_PASS'] ?? 'password';

  print('--- DEMONSTRATING ROBUST ERROR HANDLING ---\n');

  // Scenario 1: Authentication Failure
  final clientAuth = RouterOSClient(
    host: host,
    user: user,
    password: 'wrong_password_here',
    autoReconnect: false,
  );

  try {
    print('1. Testing authentication failure...');
    await clientAuth.connect();
  } on RouterOSException catch (e) {
    print('Caught Authentication Error: ${e.message}');
  } catch (e) {
    print('Caught error: $e');
  } finally {
    clientAuth.close();
  }

  // Scenario 2: Invalid Command (Trap)
  final clientTrap = RouterOSClient(
    host: host,
    user: user,
    password: pass,
    autoReconnect: false,
  );
  try {
    print('\n2. Testing invalid command (Trap)...');
    await clientTrap.connect();
    await clientTrap.talk(['/ip/wrong/path/print']);
  } on RouterOSException catch (e) {
    print('Caught Router Error: ${e.message}');
  } finally {
    clientTrap.close();
  }

  // Scenario 3: Operation Timeout
  final clientTimeout = RouterOSClient(
    host: host,
    user: user,
    password: pass,
    autoReconnect: false,
  );
  try {
    print('\n3. Testing operation timeout (forcing 1ms timeout)...');
    await clientTimeout.connect();

    // Attempt to get resources but with an impossibly short timeout
    await clientTimeout.getSystemResource().timeout(const Duration(microseconds: 1));
  } on TimeoutException catch (_) {
    print('Caught expected TimeoutException! The operation took too long.');
  } catch (e) {
    print('Caught unexpected error: $e');
  } finally {
    clientTimeout.close();
  }

  print('\nAll error handling tests completed.');
}
