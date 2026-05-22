import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

import '../models/device_node.dart';

class DiscoveryService {
  DiscoveryService();

  static const String _mdnsServiceName = '_iot-sensor._tcp.local';
  static const int _udpPort = 37020;

  Future<List<DeviceNode>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final results = <String, DeviceNode>{};

    final mdnsResults = await _discoverMdns(timeout: timeout);
    for (final node in mdnsResults) {
      _addOrMerge(results, node);
    }

    final udpResults = await _discoverUdp(timeout: timeout);
    for (final node in udpResults) {
      _addOrMerge(results, node);
    }

    return results.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<DeviceNode>> _discoverMdns({required Duration timeout}) async {
    final client = MDnsClient();
    final nodes = <String, DeviceNode>{};

    await client.start();
    try {
      final ptrRecords = await _lookupForDuration<PtrResourceRecord>(
        client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(_mdnsServiceName),
        ),
        timeout,
      );

      for (final ptr in ptrRecords) {
        final srvRecords = await _lookupForDuration<SrvResourceRecord>(
          client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          ),
          timeout,
        );

        for (final srv in srvRecords) {
          final ipv4Records = await _lookupForDuration<IPAddressResourceRecord>(
            client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
            ),
            timeout,
          );

          for (final ip in ipv4Records) {
            final hostname = srv.target.endsWith('.')
                ? srv.target.substring(0, srv.target.length - 1)
                : srv.target;
            final name = hostname.replaceAll('.local', '');
            final node = DeviceNode(
              id: hostname,
              name: name,
              ip: ip.address.address,
              hostname: hostname,
              port: srv.port,
              isOnline: true,
              lastSeen: DateTime.now(),
              rssi: 0,
              source: 'mdns',
            );
            nodes[node.id] = node;
          }
        }
      }
    } finally {
      client.stop();
    }

    return nodes.values.toList();
  }

  Future<List<DeviceNode>> _discoverUdp({required Duration timeout}) async {
    RawDatagramSocket? socket;
    final completer = Completer<List<DeviceNode>>();
    final nodes = <String, DeviceNode>{};

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.readEventsEnabled = true;
      socket.writeEventsEnabled = true;

      late final StreamSubscription<RawSocketEvent> subscription;
      subscription = socket.listen((event) {
        if (event == RawSocketEvent.write) {
          final payload = utf8.encode('VIOT_DISCOVER');
          socket?.send(payload, InternetAddress('255.255.255.255'), _udpPort);
          socket?.writeEventsEnabled = false;
        }

        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram == null) {
            return;
          }
          final node = _parseUdpDatagram(datagram);
          if (node != null) {
            nodes[node.id] = node;
          }
        }
      });

      Future<void>.delayed(timeout).then((_) async {
        await subscription.cancel();
        socket?.close();
        if (!completer.isCompleted) {
          completer.complete(nodes.values.toList());
        }
      });

      return await completer.future;
    } catch (_) {
      socket?.close();
      return nodes.values.toList();
    }
  }

  DeviceNode? _parseUdpDatagram(Datagram datagram) {
    final message = utf8.decode(datagram.data, allowMalformed: true).trim();
    if (message.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, dynamic>) {
        return DeviceNode.fromJson({
          ...decoded,
          'ip':
              decoded['ip'] ??
              decoded['sta_ip'] ??
              decoded['ap_ip'] ??
              datagram.address.address,
          'hostname':
              decoded['hostname'] ??
              decoded['mdns_host'] ??
              '${decoded['device_name'] ?? decoded['device'] ?? decoded['name'] ?? 'viot'}.local',
          'port':
              decoded['http_port'] ??
              decoded['web_port'] ??
              decoded['port'] ??
              80,
          'isOnline': true,
          'lastSeen': DateTime.now().toIso8601String(),
          'source': 'udp',
        });
      }
    } catch (_) {
      final parts = message.split(',');
      if (parts.length >= 2) {
        return DeviceNode(
          id: parts[0],
          name: parts[0],
          ip: parts[1],
          hostname: '${parts[0]}.local',
          port: 80,
          isOnline: true,
          lastSeen: DateTime.now(),
          rssi: 0,
          source: 'udp',
        );
      }
    }

    return DeviceNode(
      id: datagram.address.address,
      name: datagram.address.address,
      ip: datagram.address.address,
      hostname: datagram.address.address,
      port: 80,
      isOnline: true,
      lastSeen: DateTime.now(),
      rssi: 0,
      source: 'udp',
    );
  }

  Future<List<T>> _lookupForDuration<T>(
    Stream<T> stream,
    Duration duration,
  ) async {
    final results = <T>[];
    final subscription = stream.listen(results.add);
    await Future<void>.delayed(duration);
    await subscription.cancel();
    return results;
  }

  void _addOrMerge(Map<String, DeviceNode> results, DeviceNode node) {
    final key = _discoveryKey(node);
    final existing = results[key];
    if (existing == null) {
      results[key] = node;
      return;
    }

    results[key] = _mergeNode(existing, node);
  }

  String _discoveryKey(DeviceNode node) {
    final ip = node.ip.trim().toLowerCase();
    if (ip.isNotEmpty) {
      return 'ip:$ip';
    }

    final hostname = _normalizeHostname(node.hostname);
    if (hostname.isNotEmpty) {
      return 'host:$hostname';
    }

    return 'id:${node.id.trim().toLowerCase()}';
  }

  DeviceNode _mergeNode(DeviceNode current, DeviceNode next) {
    final preferNext =
        _sourcePriority(next.source) >= _sourcePriority(current.source);

    return DeviceNode(
      id: preferNext ? next.id : current.id,
      name: _pickText(next.name, current.name),
      ip: _pickText(next.ip, current.ip),
      hostname: _pickText(next.hostname, current.hostname),
      port: next.port != 80 ? next.port : current.port,
      isOnline: current.isOnline || next.isOnline,
      lastSeen: current.lastSeen.isAfter(next.lastSeen)
          ? current.lastSeen
          : next.lastSeen,
      rssi: _pickRssi(current.rssi, next.rssi),
      source: preferNext ? next.source : current.source,
    );
  }

  int _sourcePriority(String source) {
    return switch (source.toLowerCase()) {
      'udp' => 2,
      'mdns' => 1,
      _ => 0,
    };
  }

  String _pickText(String preferred, String fallback) {
    final normalizedPreferred = preferred.trim();
    if (normalizedPreferred.isNotEmpty) {
      return normalizedPreferred;
    }
    return fallback.trim();
  }

  int _pickRssi(int first, int second) {
    if (first == 0) {
      return second;
    }
    if (second == 0) {
      return first;
    }
    return second;
  }

  String _normalizeHostname(String hostname) {
    final normalized = hostname.trim().toLowerCase();
    if (normalized.endsWith('.local')) {
      return normalized.substring(0, normalized.length - 6);
    }
    return normalized;
  }
}
