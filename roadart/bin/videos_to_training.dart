import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:process_run/process_run.dart';
import 'package:yaml/yaml.dart';

class _Runner {
  static const String kRelativeOauthSecretPath = 'secret/oauth_secret.json';
  static const String kRelativeAccessTokenPath = 'secret/access_token.json';
  static const String kRelativeYamlPath = 'data/train_videos.yaml';

  final String rootPath;
  late String yamlPath;
  late String videosPath;

  _Runner(this.rootPath) {
    yamlPath = '$rootPath/$kRelativeYamlPath';
    videosPath = '$rootPath/data/videos';
  }

  String get oauthSecretPath => '$rootPath/$kRelativeOauthSecretPath';
  String get accessTokenPath => '$rootPath/$kRelativeAccessTokenPath';

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

  /// Return the path of the downloaded file.
  Future<String> download(String fileUrl, String localName) async {
    final pattern = RegExp(r'https://drive.google.com/file/d/([^/]+)/');
    final RegExpMatch? match = pattern.firstMatch(fileUrl);
    if (match == null) {
      throw Exception('Invalid Google drive file URL: $fileUrl');
    }
    final String fileId = match.group(1)!;
    final AuthClient authClient = await getClient();
    final driveApi = drive.DriveApi(authClient);

    Directory(videosPath).createSync(recursive: true);
    final String localPath = '$videosPath/$localName';
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
        return localPath;
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
    return localPath;
  }

  Future<void> labelVideo(String path, int beginIndex, int endIndex) async {
    final String labelBinPath = '$rootPath/roadart/bin/label.dart';
    final args = [
      '--video=$path',
      '--result=$rootPath/data/video_label_result.json',
      '--frame=$beginIndex',
      '--sam-count=${endIndex - beginIndex}'
    ];
    final cmd = 'dart $labelBinPath ${args.join(' ')}';
    await run(cmd);
  }
}

Future<double> getFps(String videoPath) async {
  if (whichSync('ffprobe') == null) {
    print('ffmpeg is not installed');
    print('See, e.g., https://formulae.brew.sh/formula/ffmpeg');
    exit(1);
  }
  final List<ProcessResult> results = await run(
      'ffprobe -v 0 -show_entries stream=r_frame_rate -of csv=p=0 $videoPath');
  final List<String> numbers = results.first.stdout.toString().split('/');
  if (numbers.length != 2) {
    throw Exception('Unexpected frame rate: ${results.first.stdout}');
  }
  return double.parse(numbers.first) / double.parse(numbers.last);
}

int parseTimeAsFrameIndex(String hhmmss, double fps) {
  final kEpoch = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration t =
      DateFormat('HH:mm:ss').parse(hhmmss, true).difference(kEpoch);
  return (t.inMilliseconds * 0.001 * fps).round();
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Please provide croad root path.');
    print('Example: dart bin/videos_to_training.dart ~/github/croad');
    exit(1);
  }

  final String rootPath = args.first;
  final runner = _Runner(rootPath);
  final dynamic videosYaml = loadYaml(File(runner.yamlPath).readAsStringSync());
  for (final entry in videosYaml['videos']) {
    final videoPath = await runner.download(entry['url'], entry['local_name']);
    final double fps = await getFps(videoPath);
    for (YamlMap range in entry['ranges']) {
      final int beginIndex = parseTimeAsFrameIndex(range['begin_time']!, fps);
      final int endIndex = parseTimeAsFrameIndex(range['end_time']!, fps);
      await runner.labelVideo(videoPath, beginIndex, endIndex);
    }
  }

  exit(0);
}
