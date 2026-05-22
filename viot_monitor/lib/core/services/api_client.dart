import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
              responseType: ResponseType.json,
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 300,
            ),
          );

  final Dio _dio;

  Future<dynamic> getJson(
    String baseUrl,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final url = _join(baseUrl, path);
    return _runRequest<dynamic>(
      method: 'GET',
      url: url,
      queryParameters: queryParameters,
      action: () => _dio.get<dynamic>(url, queryParameters: queryParameters),
    );
  }

  Future<String> getText(
    String baseUrl,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final url = _join(baseUrl, path);
    final data = await _runRequest<String>(
      method: 'GET',
      url: url,
      queryParameters: queryParameters,
      action: () => _dio.get<String>(
        url,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.plain),
      ),
    );
    return data ?? '';
  }

  Future<dynamic> postJson(
    String baseUrl,
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final url = _join(baseUrl, path);
    return _runRequest<dynamic>(
      method: 'POST',
      url: url,
      body: body,
      action: () => _dio.post<dynamic>(
        url,
        data: body,
        options: Options(contentType: Headers.jsonContentType),
      ),
    );
  }

  Future<dynamic> postForm(
    String baseUrl,
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final url = _join(baseUrl, path);
    final normalizedBody = _normalizeFormBody(body);
    return _runRequest<dynamic>(
      method: 'POST',
      url: url,
      body: normalizedBody,
      action: () => _dio.post<dynamic>(
        url,
        data: normalizedBody,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
    );
  }

  String _join(String baseUrl, String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$normalizedBase$path';
  }

  Future<T?> _runRequest<T>({
    required String method,
    required String url,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    required Future<Response<T>> Function() action,
  }) async {
    final stopwatch = Stopwatch()..start();
    _log('$method REQUEST', url, queryParameters: queryParameters, body: body);

    try {
      final response = await action();
      stopwatch.stop();
      _logResponse(
        method: method,
        url: url,
        elapsedMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        data: response.data,
      );
      return response.data;
    } on DioException catch (error) {
      stopwatch.stop();
      _logDioError(
        method: method,
        url: url,
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      rethrow;
    } catch (error, stackTrace) {
      stopwatch.stop();
      debugPrint(
        '[ApiClient] $method ERROR $url '
        'after ${stopwatch.elapsedMilliseconds}ms '
        'type=${error.runtimeType} message=$error',
      );
      debugPrint('[ApiClient] STACKTRACE $stackTrace');
      rethrow;
    }
  }

  void _log(
    String prefix,
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
  }) {
    debugPrint('[ApiClient] $prefix $url');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      debugPrint('[ApiClient] QUERY ${_preview(queryParameters)}');
    }
    if (body != null && body.isNotEmpty) {
      debugPrint('[ApiClient] BODY ${_preview(body)}');
    }
  }

  void _logResponse({
    required String method,
    required String url,
    required int elapsedMs,
    required int? statusCode,
    required Object? data,
  }) {
    debugPrint(
      '[ApiClient] $method RESPONSE $url '
      'status=${statusCode ?? 'unknown'} '
      'elapsed=${elapsedMs}ms',
    );
    debugPrint('[ApiClient] RESPONSE BODY ${_preview(data)}');
  }

  void _logDioError({
    required String method,
    required String url,
    required int elapsedMs,
    required DioException error,
  }) {
    debugPrint(
      '[ApiClient] $method ERROR $url '
      'elapsed=${elapsedMs}ms '
      'type=${error.type} '
      'message=${error.message}',
    );
    if (error.requestOptions.connectTimeout != null) {
      debugPrint(
        '[ApiClient] TIMEOUTS connect=${error.requestOptions.connectTimeout} '
        'send=${error.requestOptions.sendTimeout} '
        'receive=${error.requestOptions.receiveTimeout}',
      );
    }
    if (error.response != null) {
      debugPrint(
        '[ApiClient] ERROR RESPONSE status=${error.response?.statusCode} '
        'body=${_preview(error.response?.data)}',
      );
    }
    if (error.error != null) {
      debugPrint('[ApiClient] INNER ERROR ${error.error}');
    }
  }

  String _preview(Object? value) {
    final text = value?.toString() ?? 'null';
    if (text.length <= 500) {
      return text;
    }
    return '${text.substring(0, 500)}...<truncated>';
  }

  Map<String, dynamic> _normalizeFormBody(Map<String, dynamic> body) {
    final normalized = <String, dynamic>{};
    for (final entry in body.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is bool) {
        normalized[entry.key] = value ? '1' : '0';
        continue;
      }
      normalized[entry.key] = value.toString();
    }
    return normalized;
  }
}
