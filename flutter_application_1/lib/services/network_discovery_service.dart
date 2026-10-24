import 'dart:async';
import 'dart:io';

/// Discovers the EduTrace Python backend on the local network.
class NetworkDiscoveryService {
  static const int backendPort = 5000;
  static const Duration connectTimeout = Duration(milliseconds: 150);
  static const int maxConcurrentScans = 32;

  /// Scans active IPv4 subnets for an open backend port.
  ///
  /// Returns the first discovered backend URL, or `null` if none is found.
  Future<String?> discoverBackendUrl() async {
    // Backend varsayilan olarak yerel makinede calisir; once onu dene.
    try {
      final local = await Socket.connect(
        '127.0.0.1',
        backendPort,
        timeout: const Duration(milliseconds: 500),
      );
      await local.close();
      return 'http://127.0.0.1:$backendPort';
    } on SocketException {
      // Yerelde yok; agda ara.
    } on TimeoutException {
      // Yerelde yok; agda ara.
    }

    final subnets = await _collectSubnets();
    if (subnets.isEmpty) {
      return null;
    }

    final semaphore = _AsyncSemaphore(maxConcurrentScans);
    final completer = Completer<String?>();
    var found = false;

    for (final subnet in subnets) {
      if (found) {
        break;
      }

      for (var host = 1; host < 255; host++) {
        if (found) {
          break;
        }

        final targetIp = '$subnet.$host';
        unawaited(
          semaphore.acquire().then((_) async {
            if (found) {
              semaphore.release();
              return;
            }

            try {
              final socket = await Socket.connect(
                targetIp,
                backendPort,
                timeout: connectTimeout,
              );
              await socket.close();

              if (!found && !completer.isCompleted) {
                found = true;
                completer.complete('http://$targetIp:$backendPort');
              }
            } on SocketException {
              // Closed port — expected during sweep.
            } finally {
              semaphore.release();
            }
          }),
        );
      }
    }

    Future.delayed(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  Future<List<String>> _collectSubnets() async {
    final subnets = <String>{};

    for (final interface in await NetworkInterface.list()) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
          final ip = address.address;
          final lastDot = ip.lastIndexOf('.');
          if (lastDot > 0) {
            subnets.add(ip.substring(0, lastDot));
          }
        }
      }
    }

    return subnets.toList();
  }
}

class _AsyncSemaphore {
  _AsyncSemaphore(this._max);

  final int _max;
  int _current = 0;
  final _waitQueue = <Completer<void>>[];

  Future<void> acquire() {
    if (_current < _max) {
      _current++;
      return Future.value();
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      _waitQueue.removeAt(0).complete();
      return;
    }

    _current = (_current - 1).clamp(0, _max);
  }
}
