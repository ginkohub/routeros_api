# RouterOS API for Dart

A powerful, robust, and easy-to-use Dart package for communicating with MikroTik RouterOS via its native API protocol.

## Features

-   **Modern API Support**: Optimized for RouterOS 6.43+ (Post-6.43 login).
-   **Keep-Alive & Heartbeat**: Automatic background "pings" to prevent idle timeouts.
-   **Resilient**: Optional auto-reconnection on network failure.
-   **Real-time Streaming**: Support for continuous commands (like `monitor-traffic` or `torch`) using Dart Streams.
-   **Advanced Queries**: Built-in support for `.proplist` and RouterOS query syntax (`?`, `&`, `|`).
-   **Concurrency Safe**: Prevents command collisions on the same socket.
-   **Type Safe Exceptions**: Custom `RouterOSException` for better error handling.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  routeros_api:
    path: ./ # Or your git/pub path
```

## Getting Started

### 1. Basic Connection

```dart
import 'package:routeros_api/routeros_api.dart';

void main() async {
  final client = RouterOSClient(
    host: '192.168.88.1',
    user: 'admin',
    password: 'your_password',
  );

  try {
    await client.connect();
    print('Connected!');
    
    // Get system identity
    final identity = await client.talk(['/system/identity/print']);
    print('Router Name: ${identity.first['name']}');
    
  } finally {
    client.close();
  }
}
```

### 2. Advanced Execution (Filtering & Proplist)

Use `execute()` for a more convenient way to send parameters and filters.

```dart
// Get only running ethernet interfaces with specific fields
final interfaces = await client.execute(
  '/interface/print',
  proplist: ['name', 'mac-address', 'running'],
  queries: ['?type=ether', '?running=true', '?.and']
);
```

### 3. Real-time Monitoring (Streaming)

Use `listen()` to handle commands that produce continuous output.

```dart
final trafficStream = client.listen(['/interface/monitor-traffic', '=interface=ether1']);

await for (final update in trafficStream) {
  print('RX: ${update['rx-bits-per-second']} bps');
  // Break the loop or close client to stop listening
}
```

### 4. Error Handling

```dart
try {
  await client.talk(['/invalid/path']);
} on RouterOSException catch (e) {
  print('Router rejected command: ${e.message}');
} catch (e) {
  print('Connection error: $e');
}
```

## Configuration Options

| Option | Default | Description |
| :--- | :--- | :--- |
| `port` | `8728` | API port (use `8729` for SSL). |
| `useSsl` | `false` | Enable/Disable SSL connection. |
| `autoReconnect` | `true` | Automatically reconnect on unexpected disconnects. |
| `heartbeatInterval` | `60s` | Interval for background pings (set to `Duration.zero` to disable). |

## License

Mozilla Public License 2.0
