import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// GoogleDriveService handles sign-in and Drive AppData uploads
class GoogleDriveService {
  static const _scopes = [
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  static final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
  }

  static Future<GoogleSignInAccount?> currentUser() async {
    final current = _googleSignIn.currentUser;
    if (current != null) return current;
    return _googleSignIn.signInSilently();
  }

  static Future<drive.DriveApi> _driveApi(GoogleSignInAccount account) async {
    final headers = await account.authHeaders;
    final client = _GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  static Future<String> uploadAppData({
    required GoogleSignInAccount account,
    required List<int> bytes,
    String fileName = 'backup.enc',
  }) async {
    final api = await _driveApi(account);
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final file = drive.File()
      ..name = fileName
      ..parents = ['appDataFolder'];

    final result = await api.files.create(file, uploadMedia: media);
    return result.id ?? '';
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
