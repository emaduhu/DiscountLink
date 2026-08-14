part of '../../../main.dart';

class ApiClient {
  ApiClient(this.baseUrl);
  final String baseUrl;
  String? token;

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool showBlockingLoader = true,
  }) async {
    return _send(
      'POST',
      path,
      body: body,
      showBlockingLoader: showBlockingLoader,
    );
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool showBlockingLoader = true,
  }) async {
    return _send(
      'PUT',
      path,
      body: body,
      showBlockingLoader: showBlockingLoader,
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool showBlockingLoader = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _request(
      () => http.delete(uri, headers: _headers()),
      showBlockingLoader: showBlockingLoader,
    );
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    File? file,
    String fileField = 'image',
    bool showBlockingLoader = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _request(
      () async {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(_headers(includeContentType: false));
        request.fields.addAll(fields);
        if (file != null) {
          request.files.add(
            await http.MultipartFile.fromPath(fileField, file.path),
          );
        }
        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      },
      timeout: const Duration(minutes: 3),
      showBlockingLoader: showBlockingLoader,
    );
  }

  Future<Map<String, dynamic>> postMultipartFiles(
    String path, {
    required Map<String, String> fields,
    required List<File> files,
    String fileField = 'product_images[]',
    bool showBlockingLoader = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _request(() async {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers(includeContentType: false));
      request.fields.addAll(fields);
      for (final file in files) {
        request.files.add(
          await http.MultipartFile.fromPath(fileField, file.path),
        );
      }
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }, showBlockingLoader: showBlockingLoader);
  }

  Future<Map<String, dynamic>> postMultipartMedia(
    String path, {
    required Map<String, String> fields,
    required List<File> images,
    required List<File> videos,
    bool showBlockingLoader = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _request(
      () async {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(_headers(includeContentType: false));
        request.fields.addAll(fields);
        for (final image in images) {
          request.files.add(
            await http.MultipartFile.fromPath('product_images[]', image.path),
          );
        }
        for (final video in videos) {
          request.files.add(
            await http.MultipartFile.fromPath('product_videos[]', video.path),
          );
        }
        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      },
      timeout: const Duration(minutes: 3),
      showBlockingLoader: showBlockingLoader,
    );
  }

  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _request(
      () => http.get(uri, headers: _headers()),
      showBlockingLoader: false,
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool showBlockingLoader = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _request(() {
      final headers = _headers();
      final encoded = jsonEncode(body ?? {});
      if (method == 'PUT') {
        return http.put(uri, headers: headers, body: encoded);
      }
      return http.post(uri, headers: headers, body: encoded);
    }, showBlockingLoader: showBlockingLoader);
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() call, {
    Duration timeout = const Duration(seconds: 30),
    bool showBlockingLoader = true,
  }) async {
    if (showBlockingLoader) {
      networkActivity.begin();
      await networkActivity.waitForVisible();
    }
    try {
      late final http.Response response;
      try {
        response = await call().timeout(timeout);
      } on SocketException {
        throw Exception(
          'We could not reach DiscountLink. Check your internet connection and try again.',
        );
      } on IOException {
        throw Exception(
          'We could not reach DiscountLink. Check your internet connection and try again.',
        );
      } on TimeoutException {
        throw Exception(
          'DiscountLink is taking too long to respond. Please try again in a moment.',
        );
      } on http.ClientException {
        throw Exception(
          'We could not connect to DiscountLink right now. Please try again shortly.',
        );
      }

      final data = decodeResponse(response);
      if (response.statusCode >= 400) {
        final code = data['code']?.toString();
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            throw ApiException(
              first.first.toString(),
              statusCode: response.statusCode,
              code: code,
            );
          }
          throw ApiException(
            first.toString(),
            statusCode: response.statusCode,
            code: code,
          );
        }
        throw ApiException(
          '${data['message'] ?? 'Request failed (${response.statusCode})'}',
          statusCode: response.statusCode,
          code: code,
        );
      }
      return data;
    } finally {
      if (showBlockingLoader) {
        networkActivity.end();
      }
    }
  }

  Map<String, dynamic> decodeResponse(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } on FormatException {
      if (response.statusCode >= 500) {
        throw Exception(
          'DiscountLink is temporarily unavailable. Please try again shortly.',
        );
      }
      throw Exception(
        'DiscountLink returned an unexpected response. Please try again.',
      );
    }
  }

  Map<String, String> _headers({bool includeContentType = true}) => {
    'Accept': 'application/json',
    if (includeContentType) 'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
