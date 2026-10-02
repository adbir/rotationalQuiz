import 'package:http/http.dart' as http;

/// Downloads APL files from the SimulationCraft GitHub repository.
class SimcRemoteService {
  SimcRemoteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> fetch(Uri url) async {
    final response = await _client
        .get(url)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw SimcFetchException(url, response.statusCode);
    }
    return response.body;
  }

  void close() => _client.close();
}

class SimcFetchException implements Exception {
  SimcFetchException(this.url, this.statusCode);

  final Uri url;
  final int statusCode;

  @override
  String toString() => 'Downloading $url failed (HTTP $statusCode)';
}
