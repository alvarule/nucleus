/// Device connectivity probe used before network calls and when mapping errors.
import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper so repositories and error helpers can be tested without plugins.
abstract class ConnectivityService {
  Future<bool> hasConnection();
}

class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
