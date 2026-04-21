# RouterOS API for Dart

A powerful, robust, and production-ready Pure API Client for communicating with MikroTik RouterOS devices via the native API protocol.

## Features

- **Pure API Client**: Lightweight engine focused entirely on the MikroTik API protocol.
- **Modern API Support**: Optimized for RouterOS 6.43+ (Post-6.43 login).
- **Keep-Alive & Heartbeat**: Automatic background pings to prevent idle timeouts.
- **Resilient**: Optional auto-reconnection on unexpected network failures.
- **Timeouts**: Built-in timeout support for every operation (connection, command execution, and data reading).
- **Real-time Streaming**: Support for persistent commands (like `monitor-traffic` or `torch`) using Dart Streams.
- **Advanced Queries**: Flexible `execute()` method with support for `.proplist` and query syntax (`?`, `&`, `|`).
- **Concurrency Safe**: Internal queue system to prevent command collisions on the same socket.
- **Type Safe Exceptions**: Custom `RouterOSException` for structured error handling.
- **Zero Dependencies**: Pure Dart implementation with no external package requirements.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  routeros_api:
    git:
      url: https://github.com/ginkohub/routeros_api.git
```

## Getting Started

### 1. Basic Connection

```dart
import 'package:routeros_api/routeros_api.dart';

void main() async {
  final client = RouterOSClient(
    host: '192.168.88.1',
    user: 'admin',
    password: 'password',
  );

  try {
    await client.connect();
    // Use execute() to send commands
    final identity = await client.execute('/system/identity/print');
    print('Router Name: ${identity.first['name']}');
  } finally {
    client.close();
  }
}
```

### 2. Advanced Execution (Filtering & Proplist)

```dart
// Fetch only specific fields, filter by type, and use flags
final interfaces = await client.execute(
  '/interface/print',
  proplist: ['name', 'mac-address', 'running'],
  queries: ['?type=ether'],
  flags: ['=count-only='],
  timeout: Duration(seconds: 5),
);
```

### 3. Real-time Monitoring (Streaming)

```dart
// Use listen() for commands that produce continuous output
final trafficStream = client.listen(['/interface/monitor-traffic', '=interface=ether1']);

await for (final update in trafficStream) {
  print('RX SPEED: ${update['rx-bits-per-second']} bps');
  // Call client.close() or break the loop to stop listening
}
```

## Configuration Options

| Option | Default | Description |
| :--- | :--- | :--- |
| `port` | `8728` | API port (use `8729` for SSL). |
| `useSsl` | `false` | Enable/Disable SSL connection. |
| `autoReconnect` | `true` | Automatically reconnect on unexpected disconnects. |
| `heartbeatInterval` | `60s` | Interval for background pings. |
| `defaultTimeout` | `10s` | Default timeout for all API operations. |

## Examples

Check the `example/` folder for comprehensive use cases:
- `routeros_api_example.dart`: Basic connection and interface listing.
- `live_monitor.dart`: Real-time bandwidth monitoring with formatting.
- `network_dashboard.dart`: Aggregating data from DHCP and Hotspot modules using `execute()`.
- `error_handling_guide.dart`: Best practices for handling timeouts and router errors.

## License

This project is licensed under the [Mozilla Public License 2.0](LICENSE).
