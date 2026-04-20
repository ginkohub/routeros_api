## 0.1.3

- Refactored to a Pure API Client (removed high-level MikroTik-specific helpers from core).
- Improved protocol robustness: fixed hanging issues by properly consuming trailing words and canceling iterators.
- Added comprehensive timeout support for connection, command execution, and data reading.
- Updated all examples to use the new `execute()` and `listen()` API.
- Cleaned up Git history and project structure for a more mature release.

## 0.1.2

- Shortened package description to meet pub.dev standards.
- Updated metadata for better search engine optimization.

## 0.1.1

- Improved package documentation and examples.
- Standardized example names for pub.dev compatibility.
- Internal code cleanup and consistency fixes.

## 0.1.0

- Initial release.
- Core RouterOS API protocol implementation (Post-6.43 login).
- Support for persistent connections.
- Added `talk()` and `execute()` for command execution.
- Added `listen()` for streaming responses (e.g., monitor-traffic).
- Added Heartbeat mechanism to prevent idle timeouts.
- Added Auto-reconnection on network failure.
- Added `RouterOSException` for structured error handling.
- Documentation and examples updated.
