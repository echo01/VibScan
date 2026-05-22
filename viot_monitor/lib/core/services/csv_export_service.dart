import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dashboard_metric.dart';
import '../models/dashboard_sample.dart';
import '../models/device_node.dart';
import '../models/fft_spectrum.dart';

class CsvExportService {
  const CsvExportService();

  static const MethodChannel _channel = MethodChannel(
    'viot_monitor/mobile_wifi',
  );

  Future<CsvExportResult> saveDashboardCsv({
    required DeviceNode node,
    required List<DashboardMetric> metrics,
  }) async {
    final rows = _dashboardWideRows(
      node: node,
      samples: [DashboardSample(timestamp: DateTime.now(), metrics: metrics)],
    );

    return _saveCsvFile(
      fileName: 'dashboard_${_sanitize(node.displayName)}_${_timestamp()}.csv',
      rows: rows,
    );
  }

  Future<CsvExportResult> saveDashboardHistoryCsv({
    required DeviceNode node,
    required List<DashboardSample> samples,
  }) async {
    final rows = _dashboardWideRows(node: node, samples: samples);

    return _saveCsvFile(
      fileName:
          'dashboard_live_${_sanitize(node.displayName)}_${_timestamp()}.csv',
      rows: rows,
    );
  }

  List<List<dynamic>> _dashboardWideRows({
    required DeviceNode node,
    required List<DashboardSample> samples,
  }) {
    const preferredKeys = [
      'accel_x',
      'accel_y',
      'accel_z',
      'velocity_x',
      'velocity_y',
      'velocity_z',
      'freq_x',
      'freq_y',
      'freq_z',
      'disp_x',
      'disp_y',
      'disp_z',
      'pitch',
      'roll',
      'yaw',
      'battery',
      'rssi',
    ];
    final metricKeys = <String>[...preferredKeys];

    for (final sample in samples) {
      for (final metric in sample.metrics) {
        if (!metricKeys.contains(metric.key)) {
          metricKeys.add(metric.key);
        }
      }
    }

    return [
      ['timestamp', 'node_name', ...metricKeys],
      for (final sample in samples)
        [
          sample.timestamp.toIso8601String(),
          node.displayName,
          for (final key in metricKeys) _metricValue(sample, key),
        ],
    ];
  }

  dynamic _metricValue(DashboardSample sample, String key) {
    final metric = sample.metricByKey(key);
    if (metric == null) {
      return '';
    }
    return metric.value;
  }

  Future<CsvExportResult> saveFftCsv({
    required DeviceNode node,
    required FftSpectrum spectrum,
  }) async {
    final rows = <List<dynamic>>[
      ['timestamp', 'node_name', 'axis', 'frequency', 'amplitude'],
      for (final point in spectrum.data)
        [
          DateTime.now().toIso8601String(),
          node.displayName,
          spectrum.axis,
          point.frequency,
          point.amplitude,
        ],
    ];

    return _saveCsvFile(
      fileName:
          'fft_${_sanitize(node.displayName)}_${spectrum.axis.toLowerCase()}_${_timestamp()}.csv',
      rows: rows,
    );
  }

  Future<void> shareFile(File file, {required String subject}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject, text: subject),
    );
  }

  Future<CsvExportResult> _saveCsvFile({
    required String fileName,
    required List<List<dynamic>> rows,
  }) async {
    final csv = const ListToCsvConverter().convert(rows);
    final shareFile = await _writeShareCopy(fileName: fileName, csv: csv);
    final savedLocation = await _writeDownloadsCopy(
      fileName: fileName,
      csv: csv,
    );
    return CsvExportResult(
      fileName: fileName,
      savedLocation: savedLocation,
      shareFile: shareFile,
    );
  }

  Future<File> _writeShareCopy({
    required String fileName,
    required String csv,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(csv);
    return file;
  }

  Future<String> _writeDownloadsCopy({
    required String fileName,
    required String csv,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final location = await _channel.invokeMethod<String>(
        'saveCsvToDownloads',
        {'fileName': fileName, 'content': csv},
      );
      return location ?? 'Downloads/$fileName';
    }

    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(csv);
    return file.path;
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  String _sanitize(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }
}

class CsvExportResult {
  const CsvExportResult({
    required this.fileName,
    required this.savedLocation,
    required this.shareFile,
  });

  final String fileName;
  final String savedLocation;
  final File shareFile;
}
