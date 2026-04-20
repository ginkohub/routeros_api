/// A library for communicating with MikroTik RouterOS devices via the API protocol.
///
/// This package provides a high-level [RouterOSClient] that supports:
/// * Persistent TCP/SSL connections.
/// * Automatic heartbeats (keep-alive) and reconnection.
/// * Command execution with advanced filtering and property selection.
/// * Real-time data streaming via Dart Streams.
library routeros_api;

export 'src/routeros_api_base.dart';
