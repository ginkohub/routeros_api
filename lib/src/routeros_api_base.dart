import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Exception thrown when the RouterOS API returns an error (!trap)
/// or when a fatal protocol error occurs.
class RouterOSException implements Exception {
  /// The error message returned by the router.
  final String message;

  /// The full raw response from the router that triggered this exception.
  final List<Map<String, String>> rawResponse;

  RouterOSException(this.message, this.rawResponse);

  @override
  String toString() => 'RouterOSException: $message';
}

/// A high-level client for communicating with MikroTik RouterOS devices.
class RouterOSClient {
  final String host;
  final int port;
  final String user;
  final String password;
  final bool useSsl;
  final bool autoReconnect;
  final Duration heartbeatInterval;
  final Duration defaultTimeout;

  Socket? _socket;
  StreamIterator<Uint8List>? _iterator;
  bool _connected = false;
  bool _isIntentionalClose = false;
  Timer? _heartbeatTimer;

  // Simple command queue to prevent concurrent access to the same socket
  Completer<void>? _currentOp;

  RouterOSClient({
    required this.host,
    this.port = 8728,
    required this.user,
    required this.password,
    this.useSsl = false,
    this.autoReconnect = true,
    this.heartbeatInterval = const Duration(seconds: 60),
    this.defaultTimeout = const Duration(seconds: 10),
  });

  bool get isConnected => _connected && _socket != null;

  Future<void> connect() async {
    if (_connected) {
      return;
    }
    _isIntentionalClose = false;

    try {
      if (useSsl) {
        _socket = await SecureSocket.connect(host, port,
            onBadCertificate: (_) => true).timeout(defaultTimeout);
      } else {
        _socket = await Socket.connect(host, port).timeout(defaultTimeout);
      }

      _iterator = StreamIterator(_socket!);
      _connected = true;

      _socket!.done.then((_) {
        if (!_isIntentionalClose) {
          _handleDisconnect();
        }
      });

      await _login();
      _startHeartbeat();
    } catch (e) {
      _connected = false;
      rethrow;
    }
  }

  void _handleDisconnect() {
    _connected = false;
    _stopHeartbeat();
    if (autoReconnect && !_isIntentionalClose) {
      Future.delayed(const Duration(seconds: 5), () {
        if (!_isIntentionalClose) {
          connect().catchError((e) => null);
        }
      });
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    if (heartbeatInterval.inSeconds <= 0) {
      return;
    }

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) async {
      if (!_connected || _currentOp != null) {
        return;
      }
      try {
        await talk(['/system/identity/print'],
            timeout: const Duration(seconds: 5));
      } catch (e) {
        _socket?.destroy();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _login() async {
    final response =
        await talk(['/login', '=name=$user', '=password=$password']);
    if (response.any((r) => r.containsKey('!trap'))) {
      throw RouterOSException(
          response.firstWhere((r) => r.containsKey('message'))['message'] ??
              'Login failed',
          response);
    }
  }

  /// Sends a command and waits for the full response.
  Future<List<Map<String, String>>> talk(List<String> words,
      {Duration? timeout}) async {
    final effectiveTimeout = timeout ?? defaultTimeout;

    // Wait for current operation to finish
    while (_currentOp != null) {
      await _currentOp!.future;
    }

    _currentOp = Completer<void>();

    try {
      if (!_connected || _socket == null) {
        if (autoReconnect) {
          await connect();
        } else {
          throw Exception('Not connected');
        }
      }

      for (var word in words) {
        _writeWord(word);
      }
      _writeLength(0);

      final response = await _readSentence().timeout(effectiveTimeout);

      if (response.any((r) => r.containsKey('!trap'))) {
        final msg = response.firstWhere((r) => r.containsKey('message'),
            orElse: () => {'message': 'Unknown error'})['message']!;
        throw RouterOSException(msg, response);
      }
      return response;
    } finally {
      if (_currentOp != null && !_currentOp!.isCompleted) {
        _currentOp!.complete();
      }
      _currentOp = null;
    }
  }

  Future<List<Map<String, String>>> execute(String command,
      {Map<String, String>? params,
      List<String>? proplist,
      List<String>? queries,
      Duration? timeout}) async {
    final List<String> words = [command];
    if (proplist != null && proplist.isNotEmpty) {
      words.add('=.proplist=${proplist.join(',')}');
    }
    if (params != null) {
      params.forEach((k, v) => words.add('=$k=$v'));
    }
    if (queries != null) {
      words.addAll(queries);
    }
    return await talk(words, timeout: timeout);
  }

  Stream<Map<String, String>> listen(List<String> words) async* {
    if (!_connected || _socket == null) {
      await connect();
    }

    for (var word in words) {
      _writeWord(word);
    }
    _writeLength(0);

    Map<String, String> currentReply = {};
    while (_connected) {
      final word = await _readWord();
      if (word.isEmpty) {
        if (currentReply.isNotEmpty) {
          yield currentReply;
          currentReply = {};
        }
        continue;
      }

      if (word == '!done') {
        await _readWord();
        break;
      } else if (word == '!re' || word == '!trap') {
        if (currentReply.isNotEmpty) {
          if (currentReply.containsKey('!trap')) {
            throw RouterOSException(
                currentReply['message'] ?? 'Streaming error', [currentReply]);
          }
          yield currentReply;
          currentReply = {};
        }
        if (word == '!trap') {
          currentReply['!trap'] = 'true';
        }
      } else if (word.startsWith('=')) {
        final parts = word.substring(1).split('=');
        final key = parts[0];
        final value = parts.length > 1 ? parts.sublist(1).join('=') : '';
        currentReply[key] = value;
      } else if (word == '!fatal') {
        _connected = false;
        throw Exception('Fatal error from router');
      }
    }
  }

  void _writeWord(String word) {
    final bytes = utf8.encode(word);
    _writeLength(bytes.length);
    _socket!.add(bytes);
  }

  void _writeLength(int length) {
    if (length < 0x80) {
      _socket!.add([length]);
    } else if (length < 0x4000) {
      length |= 0x8000;
      _socket!.add([(length >> 8) & 0xFF, length & 0xFF]);
    } else if (length < 0x200000) {
      length |= 0xC00000;
      _socket!
          .add([(length >> 16) & 0xFF, (length >> 8) & 0xFF, length & 0xFF]);
    } else if (length < 0x10000000) {
      length |= 0xE0000000;
      _socket!.add([
        (length >> 24) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF
      ]);
    } else {
      _socket!.add([
        0xF0,
        (length >> 24) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF
      ]);
    }
  }

  Future<List<Map<String, String>>> _readSentence() async {
    final List<Map<String, String>> results = [];
    Map<String, String> currentReply = {};

    while (true) {
      final word = await _readWord();
      if (word.isEmpty) {
        if (currentReply.isNotEmpty) {
          results.add(currentReply);
          currentReply = {};
        } else {
          break;
        }
        continue;
      }

      if (word == '!done') {
        results.add({'!done': 'true'});
        await _readWord();
        break;
      } else if (word == '!re') {
        if (currentReply.isNotEmpty) {
          results.add(currentReply);
          currentReply = {};
        }
      } else if (word.startsWith('=')) {
        final parts = word.substring(1).split('=');
        final key = parts[0];
        final value = parts.length > 1 ? parts.sublist(1).join('=') : '';
        currentReply[key] = value;
      } else if (word == '!trap') {
        currentReply['!trap'] = 'true';
      } else if (word == '!fatal') {
        _connected = false;
        throw Exception('Fatal error from router');
      }
    }
    return results;
  }

  Future<String> _readWord() async {
    final length = await _readLength();
    if (length == 0) {
      return '';
    }
    final bytes = await _readBytes(length);
    return utf8.decode(bytes);
  }

  Future<int> _readLength() async {
    final b1 = await _readByte();
    if ((b1 & 0x80) == 0) {
      return b1;
    }
    if ((b1 & 0xC0) == 0x80) {
      return ((b1 & 0x3F) << 8) | await _readByte();
    }
    if ((b1 & 0xE0) == 0xC0) {
      return ((b1 & 0x1F) << 16) | (await _readByte() << 8) | await _readByte();
    }
    if ((b1 & 0xF0) == 0xE0) {
      return ((b1 & 0x0F) << 24) |
          (await _readByte() << 16) |
          (await _readByte() << 8) |
          await _readByte();
    }
    if ((b1 & 0xF8) == 0xF0) {
      return (await _readByte() << 24) |
          (await _readByte() << 16) |
          (await _readByte() << 8) |
          await _readByte();
    }
    return 0;
  }

  final List<int> _buffer = [];
  Future<int> _readByte() async {
    final bytes = await _readBytes(1);
    return bytes[0];
  }

  Future<Uint8List> _readBytes(int n) async {
    while (_buffer.length < n) {
      if (await _iterator!.moveNext().timeout(defaultTimeout)) {
        _buffer.addAll(_iterator!.current);
      } else {
        _connected = false;
        throw Exception('Connection closed');
      }
    }
    final result = Uint8List.fromList(_buffer.sublist(0, n));
    _buffer.removeRange(0, n);
    return result;
  }

  /// Closes the connection and stops the heartbeat timer.
  void close() {
    _isIntentionalClose = true;
    _stopHeartbeat();
    _iterator?.cancel();
    _socket?.destroy();
    _socket = null;
    _connected = false;
  }

  // --- Helper Methods ---

  /// Retrieves all network interfaces.
  Future<List<Map<String, String>>> getInterfaces() =>
      execute('/interface/print');

  /// Retrieves active hotspot users.
  Future<List<Map<String, String>>> getHotspotActiveUsers() =>
      execute('/ip/hotspot/active/print');

  /// Retrieves traffic stats for a specific interface.
  Future<List<Map<String, String>>> getInterfaceTraffic(String interface) =>
      execute('/interface/monitor-traffic',
          params: {'interface': interface, 'once': ''});

  /// Retrieves the ARP table.
  Future<List<Map<String, String>>> getArpTable() => execute('/ip/arp/print');

  /// Retrieves all DHCP leases.
  Future<List<Map<String, String>>> getDHCPLeases() =>
      execute('/ip/dhcp-server/lease/print');

  /// Retrieves system resources.
  Future<Map<String, String>> getSystemResource() async {
    final response = await execute('/system/resource/print');
    return response.isNotEmpty ? response.first : {};
  }
}
