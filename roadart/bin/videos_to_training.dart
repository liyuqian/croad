import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:process_run/process_run.dart';
import 'package:yaml/yaml.dart';

class _Runner {
  static const String kRelativeOauthSecretPath = 'secret/oauth_secret.json';
  static const String kRelativeAccessTokenPath = 'secret/access_token.json';

  final String yamlPath;

  _Runner(this.yamlPath) {
    _rootPath = File(yamlPath).parent.parent.path;
    _videosPath = '$_rootPath/data/videos';
  }

  String get oauthSecretPath => '$_rootPath/$kRelativeOauthSecretPath';
  String get accessTokenPath => '$_rootPath/$kRelativeAccessTokenPath';

  Future<Map<String, dynamic>> loadOauthSecretJson() async {
    if (whichSync('gcloud') == null) {
      print('gcloud is not installed');
      print('See https://cloud.google.com/sdk/docs/install');
      print('and https://formulae.brew.sh/cask/google-cloud-sdk');
      exit(1);
    }

    if (!File(oauthSecretPath).existsSync()) {
      /// May need the following gcloud setup
      /// ```
      /// gcloud auth login
      /// gcloud config set project airyfast
      /// ```
      await run('''
      gcloud secrets versions access 1 \\
        --secret oauth_client_secret --out-file $oauthSecretPath''');
    }

    return jsonDecode(File(oauthSecretPath).readAsStringSync());
  }

  Future<AuthClient> getClient() async {
    if (File(accessTokenPath).existsSync()) {
      final Map<String, dynamic> tokenJson =
          jsonDecode(File(accessTokenPath).readAsStringSync());
      final AccessToken token = AccessToken.fromJson(tokenJson);
      if (!token.hasExpired) {
        return authenticatedClient(
            http.Client(), AccessCredentials(token, null, []));
      }
    }

    final Map<String, dynamic> secretJson = await loadOauthSecretJson();
    final String id = secretJson['installed']['client_id'];
    final String secret = secretJson['installed']['client_secret'];
    final clientId = ClientId(id, secret);
    const scopes = [drive.DriveApi.driveReadonlyScope];

    final authClient =
        await clientViaUserConsent(clientId, scopes, (String url) {
      print('Please go to the following URL and grant access:');
      print('  => $url');
    });

    File(accessTokenPath).writeAsStringSync(
        jsonEncode(authClient.credentials.accessToken.toJson()));
    print('Authenticated. Token saved to $accessTokenPath');
    return authClient;
  }

  Future<String> getSha256(String path) async {
    // Use sha256 command if available since it's much faster.
    if (whichSync('sha256') != null) {
      final ProcessResult result = (await run('sha256 -q $path')).first;
      return result.stdout.toString().trim();
    }
    final Digest digest = await File(path).openRead().transform(sha256).first;
    return digest.toString();
  }

  Future<void> download(String fileUrl, String localName) async {
    final pattern = RegExp(r'https://drive.google.com/file/d/([^/]+)/');
    final RegExpMatch? match = pattern.firstMatch(fileUrl);
    if (match == null) {
      throw Exception('Invalid Google drive file URL: $fileUrl');
    }
    final String fileId = match.group(1)!;
    final AuthClient authClient = await getClient();
    final driveApi = drive.DriveApi(authClient);

    final String localPath = '$_videosPath/$localName';
    final localFile = File(localPath);
    if (localFile.existsSync()) {
      print('$localPath already exists.');
      final String localSha256 = await getSha256(localPath);
      print('Local sha256 computed.');
      final driveFile = (await driveApi.files
          .get(fileId, $fields: 'sha256Checksum')) as drive.File;
      final String remoteSha256 = driveFile.sha256Checksum!;
      if (localSha256 == remoteSha256) {
        print('Skip $localPath that matches sha256.');
        return;
      } else {
        print('$localPath sha256 mismatch: $localSha256 != $remoteSha256');
      }
    }

    final media = (await driveApi.files.get(fileId,
        downloadOptions: drive.DownloadOptions.fullMedia)) as drive.Media;

    print('Downloading $localPath');
    final sink = localFile.openWrite();
    await media.stream.pipe(sink);
    await sink.close();
  }

  late String _rootPath;
  late String _videosPath;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    throw Exception('Please provide train_videos.yaml path.');
  }

  final String yamlPath = args.first;
  final runner = _Runner(yamlPath);
  final dynamic videosYaml = loadYaml(File(args[0]).readAsStringSync());
  for (final entry in videosYaml['videos']) {
    await runner.download(entry['url'], entry['local_name']);
  }

  exit(0);
}
