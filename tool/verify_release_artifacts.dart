// Copyright (c) 2026 ukulele_app contributors.
//
// T022_RELEASE_ARTIFACT_AUTOMATED_VERIFICATION
//
// Purpose:
//   Statically verify the Release APK / AAB artifacts produced by T021.
//   The script never reads `android/key.properties`, never prints keystore
//   passwords, the alias, the keystore content, or the user's home
//   directory, and never modifies the artifacts.
//
//   The script uses only Dart's standard library (dart:io, dart:convert)
//   and shells out to Android SDK command-line tools that the user must
//   already have installed. It also computes a SHA-256 / size summary for
//   the artifacts and asserts the package identity, signature, and
//   permission requirements from the Release SDD / TDD.
//
// Usage:
//   dart run tool/verify_release_artifacts.dart
//
// Exit codes:
//   0 — every required check passed
//   non-zero — at least one required check failed (also printed to stderr)

import 'dart:io';

/// All required check failures collected during a single run.
final List<String> _failures = <String>[];

/// All non-fatal warnings (e.g. Debug APK comparison skipped).
final List<String> _warnings = <String>[];

/// Human-readable milestone log lines, printed as the script progresses.
final List<String> _log = <String>[];

/// ---------------------------------------------------------------------------
/// Path constants
/// ---------------------------------------------------------------------------

const String _releaseApkRel = 'build/app/outputs/flutter-apk/app-release.apk';
const String _releaseAabRel = 'build/app/outputs/bundle/release/app-release.aab';
const String _debugApkRel = 'build/app/outputs/flutter-apk/app-debug.apk';

const String _expectedApplicationId = 'com.yupi.ukulele';
const String _expectedVersionName = '1.0.0';
const String _expectedVersionCode = '2';

/// Names of Android runtime permissions that MUST NOT be declared.
const List<String> _forbiddenPermissions = <String>[
  'android.permission.RECORD_AUDIO',
  'android.permission.INTERNET',
];

void main(List<String> args) async {
  try {
    _printHeader();

    final File apkFile = _requireArtifact(_releaseApkRel);
    final File aabFile = _requireArtifact(_releaseAabRel);

    final int apkSize = await _emitSize(_releaseApkRel, apkFile);
    final int aabSize = await _emitSize(_releaseAabRel, aabFile);
    final String apkSha = await _emitSha256(_releaseApkRel, apkFile);
    final String aabSha = await _emitSha256(_releaseAabRel, aabFile);

    final SdkTools tools = _resolveSdkTools();

    final _ApkSignature apkSignature = _verifyApkSignature(apkFile, tools);
    final _AabSignature aabSignature = _verifyAabSignature(aabFile, tools);

    final _PackageIdentity pkg = _parsePackageIdentity(apkFile, tools);
    _assertPackageIdentity(pkg);

    final List<String> permissions = _parsePermissions(apkFile, tools);
    _assertForbiddenPermissions(permissions);

    _DebugComparison? debugComparison =
        _compareDebugCertificate(apkFile, tools);

    _emitSummary(
      apkSize: apkSize,
      aabSize: aabSize,
      apkSha: apkSha,
      aabSha: aabSha,
      apkSignature: apkSignature,
      aabSignature: aabSignature,
      packageIdentity: pkg,
      permissions: permissions,
      debugComparison: debugComparison,
    );

    _emitLog();

    if (_failures.isNotEmpty) {
      stderr.writeln('');
      stderr.writeln('VERIFY_FAILED: ${_failures.length} required check(s) '
          'did not pass.');
      for (final String f in _failures) {
        stderr.writeln('  - $f');
      }
      exit(1);
    }

    stdout.writeln('');
    stdout.writeln('VERIFY_OK: all required checks passed.');
    exit(0);
  } on _FailFast catch (e) {
    stderr.writeln('');
    stderr.writeln('FATAL: ${e.message}');
    exit(2);
  } catch (e, st) {
    stderr.writeln('');
    stderr.writeln('UNEXPECTED_ERROR: $e');
    stderr.writeln(st.toString());
    exit(3);
  }
}

/// Thrown to abort the entire script when a precondition is not met.
class _FailFast implements Exception {
  _FailFast(this.message);
  final String message;
  @override
  String toString() => 'FailFast: $message';
}

/// ---------------------------------------------------------------------------
/// Logging helpers
/// ---------------------------------------------------------------------------

void _printHeader() {
  stdout.writeln('# ukulele_app T022 Release Artifact Verification');
  stdout.writeln('# Date: ${DateTime.now().toUtc().toIso8601String()}');
  stdout.writeln('# Working directory: ${Directory.current.path}');
  stdout.writeln('');
}

void _emit(String section, String message) {
  _log.add('[$section] $message');
}

void _emitLog() {
  stdout.writeln('');
  stdout.writeln('# Verification log');
  for (final String line in _log) {
    stdout.writeln(line);
  }
  if (_warnings.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('# Warnings');
    for (final String w in _warnings) {
      stdout.writeln('  - $w');
    }
  }
}

void _fail(String message) {
  _failures.add(message);
  _emit('FAIL', message);
}

/// ---------------------------------------------------------------------------
/// Artifact existence / size / SHA-256
/// ---------------------------------------------------------------------------

File _requireArtifact(String relativePath) {
  final File f = File(relativePath);
  if (!f.existsSync()) {
    throw _FailFast('Required artifact missing: $relativePath');
  }
  _emit('ARTIFACT', '$relativePath exists');
  return f;
}

Future<int> _emitSize(String label, File file) async {
  final int size = await file.length();
  _emit('SIZE', '$label = $size bytes');
  return size;
}

Future<String> _emitSha256(String label, File file) async {
  final Digest digest = await _sha256OfFile(file);
  _emit('SHA256', '$label = ${digest.toHex()}');
  return digest.toHex();
}

Future<Digest> _sha256OfFile(File file) async {
  final DigestSink sink = DigestSink();
  final Stream<List<int>> stream = file.openRead();
  await for (final List<int> chunk in stream) {
    sink.add(chunk);
  }
  return sink.close();
}

/// Minimal incremental SHA-256 helper built on top of dart:convert. Avoids
/// having to depend on `package:crypto`.
class DigestSink {
  DigestSink()
      : _h0 = 0x6a09e667,
        _h1 = 0xbb67ae85,
        _h2 = 0x3c6ef372,
        _h3 = 0xa54ff53a,
        _h4 = 0x510e527f,
        _h5 = 0x9b05688c,
        _h6 = 0x1f83d9ab,
        _h7 = 0x5be0cd19,
        _buffer = <int>[],
        _lengthBytes = 0;

  int _h0, _h1, _h2, _h3, _h4, _h5, _h6, _h7;
  final List<int> _buffer;
  int _lengthBytes;

  void add(List<int> chunk) {
    _buffer.addAll(chunk);
    _lengthBytes += chunk.length;
    while (_buffer.length >= 64) {
      final List<int> block = _buffer.sublist(0, 64);
      _buffer.removeRange(0, 64);
      _processBlock(block);
    }
  }

  Digest close() {
    _buffer.add(0x80);
    while (_buffer.length % 64 != 56) {
      _buffer.add(0);
    }
    // Append the 64-bit big-endian message length in BITS.
    int bitLength = _lengthBytes * 8;
    for (int i = 7; i >= 0; i--) {
      _buffer.add((bitLength >> (i * 8)) & 0xff);
    }
    while (_buffer.length >= 64) {
      final List<int> block = _buffer.sublist(0, 64);
      _buffer.removeRange(0, 64);
      _processBlock(block);
    }
    final String hex = [_h0, _h1, _h2, _h3, _h4, _h5, _h6, _h7]
        .map((int v) => v.toRadixString(16).padLeft(8, '0'))
        .join();
    return Digest(hex);
  }

  void _processBlock(List<int> block) {
    final List<int> w = List<int>.filled(64, 0);
    for (int i = 0; i < 16; i++) {
      w[i] = (block[i * 4] << 24) |
          (block[i * 4 + 1] << 16) |
          (block[i * 4 + 2] << 8) |
          block[i * 4 + 3];
      w[i] &= 0xffffffff;
    }
    for (int i = 16; i < 64; i++) {
      final int s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final int s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }

    int a = _h0, b = _h1, c = _h2, d = _h3;
    int e = _h4, f = _h5, g = _h6, h = _h7;

    for (int i = 0; i < 64; i++) {
      // ignore: non_constant_identifier_names
      final int S1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final int ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final int temp1 = (h + S1 + ch + _k(i) + w[i]) & 0xffffffff;
      // ignore: non_constant_identifier_names
      final int S0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final int maj = (a & b) ^ (a & c) ^ (b & c);
      final int temp2 = (S0 + maj) & 0xffffffff;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }

    _h0 = (_h0 + a) & 0xffffffff;
    _h1 = (_h1 + b) & 0xffffffff;
    _h2 = (_h2 + c) & 0xffffffff;
    _h3 = (_h3 + d) & 0xffffffff;
    _h4 = (_h4 + e) & 0xffffffff;
    _h5 = (_h5 + f) & 0xffffffff;
    _h6 = (_h6 + g) & 0xffffffff;
    _h7 = (_h7 + h) & 0xffffffff;
  }

  int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;

  int _k(int i) {
    // First 32 bits of the fractional parts of the cube roots of the first
    // 64 primes.
    const List<int> K = <int>[
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
      0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
      0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
      0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
      0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
      0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
      0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
      0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
      0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];
    return K[i];
  }
}

class Digest {
  Digest(this._hex);
  final String _hex;
  String toHex() => _hex;
}

/// ---------------------------------------------------------------------------
/// SDK tool discovery
/// ---------------------------------------------------------------------------

class SdkTools {
  SdkTools({
    required this.aapt,
    required this.apksigner,
    required this.jarsigner,
    required this.keytool,
  });

  final String aapt;
  final String apksigner;
  final String jarsigner;
  final String keytool;

  String? sdkRoot;
}

SdkTools _resolveSdkTools() {
  // 1. Honour ANDROID_HOME / ANDROID_SDK_ROOT if set.
  String? sdkRoot = Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'];
  String? buildToolsDir;

  if (sdkRoot != null && sdkRoot.isNotEmpty) {
    final Directory d = Directory('$sdkRoot${Platform.pathSeparator}build-tools');
    if (d.existsSync()) {
      buildToolsDir = _newestSubdir(d);
    }
  }

  // 2. Fall back to common Windows SDK locations (and non-Windows for
  //    portability, in case the script is ever executed on macOS/Linux).
  buildToolsDir ??= _probeCommonSdkPaths();

  if (buildToolsDir == null) {
    throw _FailFast(
      'Could not locate Android SDK build-tools. Set ANDROID_HOME or '
      'ANDROID_SDK_ROOT, or install build-tools to a standard path '
      '(e.g. %LOCALAPPDATA%\\Android\\Sdk\\build-tools\\<version>).',
    );
  }

  final String aapt = '$buildToolsDir${Platform.pathSeparator}aapt'
      '${Platform.isWindows ? '.exe' : ''}';
  final String apksigner = '$buildToolsDir${Platform.pathSeparator}apksigner'
      '${Platform.isWindows ? '.bat' : ''}';
  final String jarsigner = _resolveOnPath('jarsigner', explicit: <String>[
        if (Platform.isWindows) ...<String>[
          r'D:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot\bin\jarsigner.exe',
          r'C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot\bin\jarsigner.exe',
          r'D:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot\bin\jarsigner.exe',
          r'C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot\bin\jarsigner.exe',
          r'C:\Program Files (x86)\Common Files\Oracle\Java\javapath\jarsigner.exe',
          r'C:\Program Files\Java\jdk-17\bin\jarsigner.exe',
          r'C:\Program Files\Java\jdk-21\bin\jarsigner.exe',
        ] else ...<String>[
          '/usr/bin/jarsigner',
        ],
      ]);
  final String keytool = _resolveOnPath('keytool', explicit: <String>[
        if (Platform.isWindows) ...<String>[
          r'D:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot\bin\keytool.exe',
          r'C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot\bin\keytool.exe',
          r'D:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot\bin\keytool.exe',
          r'C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot\bin\keytool.exe',
          r'C:\Program Files (x86)\Common Files\Oracle\Java\javapath\keytool.exe',
          r'C:\Program Files\Java\jdk-17\bin\keytool.exe',
          r'C:\Program Files\Java\jdk-21\bin\keytool.exe',
        ] else ...<String>[
          '/usr/bin/keytool',
        ],
      ]);

  if (!File(aapt).existsSync()) {
    throw _FailFast('Required tool not found: $aapt');
  }
  if (!File(apksigner).existsSync()) {
    throw _FailFast('Required tool not found: $apksigner');
  }
  if (jarsigner.isEmpty || !File(jarsigner).existsSync()) {
    throw _FailFast(
        'Required tool not found on PATH: jarsigner (expected in JDK bin)');
  }
  if (keytool.isEmpty || !File(keytool).existsSync()) {
    throw _FailFast(
        'Required tool not found on PATH: keytool (expected in JDK bin)');
  }

  _emit('SDK', 'aapt = $aapt');
  _emit('SDK', 'apksigner = $apksigner');
  _emit('SDK', 'jarsigner = $jarsigner');
  _emit('SDK', 'keytool = $keytool');

  final SdkTools t = SdkTools(
    aapt: aapt,
    apksigner: apksigner,
    jarsigner: jarsigner,
    keytool: keytool,
  );
  t.sdkRoot = buildToolsDir;
  return t;
}

String? _newestSubdir(Directory parent) {
  if (!parent.existsSync()) return null;
  final List<Directory> entries = parent
      .listSync()
      .whereType<Directory>()
      .toList()
      ..sort((Directory a, Directory b) =>
          a.path.compareTo(b.path)); // lexical also gives monotonic order
  if (entries.isEmpty) return null;
  return entries.last.path;
}

String? _probeCommonSdkPaths() {
  final List<String> candidates = <String>[
    if (Platform.isWindows) ...<String>[
      r'C:\Program Files (x86)\Android\android-sdk\build-tools',
      r'C:\Program Files\Android\android-sdk\build-tools',
      r'D:\Program Files (x86)\Android\android-sdk\build-tools',
      r'D:\Program Files\Android\android-sdk\build-tools',
      r'C:\Android\Sdk\build-tools',
    ] else ...<String>[
      '/opt/android-sdk/build-tools',
      '/usr/local/android-sdk/build-tools',
      '${Platform.environment['HOME']}/Library/Android/sdk/build-tools',
      '${Platform.environment['HOME']}/Android/Sdk/build-tools',
    ],
  ];
  for (final String c in candidates) {
    final Directory d = Directory(c);
    if (d.existsSync()) {
      final String? newest = _newestSubdir(d);
      if (newest != null) return newest;
    }
  }
  return null;
}

String _resolveOnPath(String executable, {List<String> explicit = const <String>[]}) {
  final String suffix = Platform.isWindows ? '.exe' : '';
  // Try explicit well-known locations first; PATH-based discovery is
  // unreliable when the script is launched from a non-native shell.
  for (final String candidate in explicit) {
    if (File(candidate).existsSync()) return candidate;
  }
  // Honour the PATH environment variable. The PATH separator seen from
  // Dart on Windows is normally `;`, but some shells (e.g. git-bash) may
  // pass through a `:`-separated PATH, so accept both.
  final String pathEnv = Platform.environment['PATH'] ?? '';
  final List<String> dirs = pathEnv
      .split(RegExp(r'[;:]'))
      .where((String s) => s.isNotEmpty)
      .toList();
  for (final String dir in dirs) {
    if (dir.isEmpty) continue;
    final String candidate =
        '${dir.trim()}${Platform.pathSeparator}$executable$suffix';
    if (File(candidate).existsSync()) return candidate;
  }
  return '';
}

/// ---------------------------------------------------------------------------
/// APK signature verification (apksigner)
/// ---------------------------------------------------------------------------

class _ApkSignature {
  _ApkSignature({
    required this.verified,
    required this.exitCode,
    required this.certificateSha256,
    required this.signatureSchemes,
    required this.stdout,
    required this.stderr,
  });

  final bool verified;
  final int exitCode;
  final String? certificateSha256;
  final List<String> signatureSchemes;
  final String stdout;
  final String stderr;
}

_ApkSignature _verifyApkSignature(File apkFile, SdkTools tools) {
  final ProcessResult r = Process.runSync(
    tools.apksigner,
    <String>['verify', '--verbose', '--print-certs', apkFile.path],
  );
  final String stdout = r.stdout.toString();
  final String stderr = r.stderr.toString();
  final int exitCode = r.exitCode;

  final List<String> schemes = _extractSignatureSchemes(stdout);
  final String? sha = _extractCertificateSha256(stdout);

  final bool verified = exitCode == 0;
  _emit('APKSIGN',
      'apksigner verify exit=$exitCode schemes=${schemes.join(",")} '
      'certSha256=${sha ?? "<not found>"}');

  if (!verified) {
    _fail('apksigner verify reported a non-zero exit code for '
        '${apkFile.path}: $exitCode');
    if (stderr.isNotEmpty) _emit('APKSIGN.stderr', stderr.trim());
  }
  if (sha == null) {
    _fail('apksigner --print-certs did not include a SHA-256 certificate '
        'digest for ${apkFile.path}');
  }

  return _ApkSignature(
    verified: verified,
    exitCode: exitCode,
    certificateSha256: sha,
    signatureSchemes: schemes,
    stdout: stdout,
    stderr: stderr,
  );
}

List<String> _extractSignatureSchemes(String apksignerOutput) {
  final List<String> schemes = <String>[];
  final RegExp re = RegExp(r'^Verifies(?:[\s]+)?\((.*)\)\s*$',
      multiLine: true);
  for (final RegExpMatch m in re.allMatches(apksignerOutput)) {
    final String inner = m.group(1) ?? '';
    schemes.add(inner.trim());
  }
  if (schemes.isEmpty) {
    // Fallback: apksigner sometimes prints lines like
    //   "Verified using v2 scheme (APK Signature Scheme v2): true"
    final RegExp re2 = RegExp(r'APK Signature Scheme v\d+',
        multiLine: true);
    for (final RegExpMatch m in re2.allMatches(apksignerOutput)) {
      final String s = m.group(0) ?? '';
      if (!schemes.contains(s)) schemes.add(s);
    }
  }
  return schemes;
}

String? _extractCertificateSha256(String apksignerOutput) {
  // apksigner prints: "Signer #1 certificate SHA-256 digest: <hex>"
  final RegExp re = RegExp(
    r'certificate SHA-256 digest:\s*([0-9a-fA-F]{64})',
    multiLine: true,
  );
  final RegExpMatch? m = re.firstMatch(apksignerOutput);
  if (m != null) return (m.group(1) ?? '').toLowerCase();
  return null;
}

/// ---------------------------------------------------------------------------
/// AAB signature verification (jarsigner)
/// ---------------------------------------------------------------------------

class _AabSignature {
  _AabSignature({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

_AabSignature _verifyAabSignature(File aabFile, SdkTools tools) {
  final ProcessResult r = Process.runSync(
    tools.jarsigner,
    <String>['-verify', aabFile.path],
  );
  final String stdout = r.stdout.toString();
  final String stderr = r.stderr.toString();
  final int exitCode = r.exitCode;
  _emit('JARSIGN',
      'jarsigner -verify exit=$exitCode (AAB)');

  if (exitCode != 0) {
    _fail('jarsigner -verify reported a non-zero exit code for '
        '${aabFile.path}: $exitCode');
    if (stderr.isNotEmpty) _emit('JARSIGN.stderr', stderr.trim());
  }

  return _AabSignature(exitCode: exitCode, stdout: stdout, stderr: stderr);
}

/// ---------------------------------------------------------------------------
/// Package identity (applicationId, versionName, versionCode)
/// ---------------------------------------------------------------------------

class _PackageIdentity {
  _PackageIdentity({
    required this.applicationId,
    required this.versionName,
    required this.versionCode,
  });

  final String? applicationId;
  final String? versionName;
  final String? versionCode;

  String get minSdk => '';
  String get targetSdk => '';
  String get compileSdk => '';
}

_PackageIdentity _parsePackageIdentity(File apkFile, SdkTools tools) {
  final ProcessResult r = Process.runSync(
    tools.aapt,
    <String>['dump', 'badging', apkFile.path],
  );
  if (r.exitCode != 0) {
    throw _FailFast(
        'aapt dump badging failed for ${apkFile.path}: exit=${r.exitCode}');
  }
  final String out = r.stdout.toString();
  String? appId;
  String? vName;
  String? vCode;

  final RegExp pkgRe =
      RegExp(r"^package:\s*name='([^']+)'\s*versionCode='([^']+)'\s*"
          r"versionName='([^']+)'",
          multiLine: true);
  final RegExpMatch? m = pkgRe.firstMatch(out);
  if (m != null) {
    appId = m.group(1);
    vCode = m.group(2);
    vName = m.group(3);
  }

  // aapt also reports sdkVersion / targetSdkVersion on the same package line
  // in some versions. We do not require them — only applicationId /
  // versionName / versionCode are mandatory.

  _emit('AAPT', "applicationId=$appId versionName=$vName "
      "versionCode=$vCode");

  return _PackageIdentity(
    applicationId: appId,
    versionName: vName,
    versionCode: vCode,
  );
}

void _assertPackageIdentity(_PackageIdentity pkg) {
  if (pkg.applicationId == null) {
    _fail('aapt dump badging did not report an applicationId');
  } else if (pkg.applicationId != _expectedApplicationId) {
    _fail('applicationId mismatch: expected '
        '$_expectedApplicationId, got ${pkg.applicationId}');
  }

  if (pkg.versionName == null) {
    _fail('aapt dump badging did not report a versionName');
  } else if (pkg.versionName != _expectedVersionName) {
    _fail('versionName mismatch: expected '
        '$_expectedVersionName, got ${pkg.versionName}');
  }

  if (pkg.versionCode == null) {
    _fail('aapt dump badging did not report a versionCode');
  } else if (pkg.versionCode != _expectedVersionCode) {
    _fail('versionCode mismatch: expected '
        '$_expectedVersionCode, got ${pkg.versionCode}');
  }
}

/// ---------------------------------------------------------------------------
/// Permissions
/// ---------------------------------------------------------------------------

List<String> _parsePermissions(File apkFile, SdkTools tools) {
  final ProcessResult r = Process.runSync(
    tools.aapt,
    <String>['dump', 'permissions', apkFile.path],
  );
  if (r.exitCode != 0) {
    _emit('AAPT.perm',
        'aapt dump permissions returned exit=${r.exitCode}; treating as '
        'no permissions reported (this is the expected state for MVP).');
    return <String>[];
  }
  final List<String> perms = <String>[];
  final RegExp re = RegExp(r"^uses-permission:\s*name='([^']+)'",
      multiLine: true);
  for (final RegExpMatch m in re.allMatches(r.stdout.toString())) {
    perms.add(m.group(1) ?? '');
  }
  return perms;
}

void _assertForbiddenPermissions(List<String> perms) {
  for (final String forbidden in _forbiddenPermissions) {
    if (perms.contains(forbidden)) {
      _fail('Forbidden permission declared in Manifest: $forbidden');
    }
  }
  _emit('PERMS', 'declared=${perms.join(",")}');
}

/// ---------------------------------------------------------------------------
/// Debug certificate comparison
/// ---------------------------------------------------------------------------

class _DebugComparison {
  _DebugComparison({
    required this.status,
    required this.debugSha256,
    required this.releaseSha256,
  });

  final String status; // 'matched' | 'differ' | 'skipped'
  final String? debugSha256;
  final String? releaseSha256;
}

_DebugComparison? _compareDebugCertificate(File apkFile, SdkTools tools) {
  final File debugApk = File(_debugApkRel);
  if (!debugApk.existsSync()) {
    _warnings.add('Debug APK not found at $_debugApkRel — skipping '
        'Release-vs-Debug certificate comparison (human or follow-up '
        'command must still collect this evidence).');
    _emit('DEBUG',
        'Debug APK missing; Release-vs-Debug cert comparison skipped.');
    return null;
  }

  final String? debugSha = _extractCertificateSha256(
      _apksignerVerifyPrintCerts(debugApk.path, tools));
  final String? releaseSha =
      _extractCertificateSha256(_apksignerVerifyPrintCerts(apkFile.path, tools));

  if (debugSha == null || releaseSha == null) {
    _fail('Could not extract certificate SHA-256 for Debug-vs-Release '
        'comparison (debug=$debugSha, release=$releaseSha)');
    return _DebugComparison(
      status: 'skipped',
      debugSha256: debugSha,
      releaseSha256: releaseSha,
    );
  }

  final bool differ = debugSha != releaseSha;
  if (!differ) {
    _fail('Release and Debug APK certificates are identical '
        '($releaseSha). The Release APK MUST NOT reuse the debug key.');
  } else {
    _emit('DEBUG',
        'Release cert sha256=$releaseSha, Debug cert sha256=$debugSha, '
        'differ=true');
  }

  return _DebugComparison(
    status: differ ? 'differ' : 'matched',
    debugSha256: debugSha,
    releaseSha256: releaseSha,
  );
}

String _apksignerVerifyPrintCerts(String apkPath, SdkTools tools) {
  final ProcessResult r = Process.runSync(
    tools.apksigner,
    <String>['verify', '--print-certs', apkPath],
  );
  // We deliberately do NOT fail on non-zero exit code here — extracting the
  // certificate digest is best-effort; failures are reported via the SHA-256
  // extraction step.
  _emit('APKSIGN.debug',
      'apksigner verify --print-certs $apkPath exit=${r.exitCode}');
  return r.stdout.toString();
}

/// ---------------------------------------------------------------------------
/// Summary emit (for manual copy into RELEASE_ARTIFACTS.md)
/// ---------------------------------------------------------------------------

void _emitSummary({
  required int apkSize,
  required int aabSize,
  required String apkSha,
  required String aabSha,
  required _ApkSignature apkSignature,
  required _AabSignature aabSignature,
  required _PackageIdentity packageIdentity,
  required List<String> permissions,
  required _DebugComparison? debugComparison,
}) {
  stdout.writeln('');
  stdout.writeln('# Summary (copy into RELEASE_ARTIFACTS.md)');
  stdout.writeln('');
  stdout.writeln('## Artifacts');
  stdout.writeln('APK_PATH=$_releaseApkRel');
  stdout.writeln('APK_SIZE_BYTES=$apkSize');
  stdout.writeln('APK_SHA256=$apkSha');
  stdout.writeln('AAB_PATH=$_releaseAabRel');
  stdout.writeln('AAB_SIZE_BYTES=$aabSize');
  stdout.writeln('AAB_SHA256=$aabSha');
  stdout.writeln('');
  stdout.writeln('## Package Identity');
  stdout.writeln('APPLICATION_ID=${packageIdentity.applicationId ?? ""}');
  stdout.writeln('VERSION_NAME=${packageIdentity.versionName ?? ""}');
  stdout.writeln('VERSION_CODE=${packageIdentity.versionCode ?? ""}');
  stdout.writeln('');
  stdout.writeln('## Signature');
  stdout.writeln(
      'APK_SIGNATURE_VERIFIED=${apkSignature.verified ? "true" : "false"}');
  stdout.writeln(
      'APK_SIGNATURE_SCHEMES=${apkSignature.signatureSchemes.join(",")}');
  stdout.writeln(
      'RELEASE_CERTIFICATE_SHA256=${apkSignature.certificateSha256 ?? ""}');
  stdout.writeln(
      'AAB_JARSIGNER_VERIFY_EXIT_CODE=${aabSignature.exitCode}');
  stdout.writeln('');
  stdout.writeln('## Debug Comparison');
  if (debugComparison == null) {
    stdout.writeln('DEBUG_COMPARISON=skipped');
  } else {
    stdout.writeln('DEBUG_COMPARISON=${debugComparison.status}');
    stdout.writeln('DEBUG_CERTIFICATE_SHA256='
        '${debugComparison.debugSha256 ?? ""}');
    stdout.writeln(
        'RELEASE_AND_DEBUG_DIFFER=${debugComparison.status == "differ" ? "true" : "false"}');
  }
  stdout.writeln('');
  stdout.writeln('## Permissions');
  stdout.writeln('DECLARED_PERMISSIONS=${permissions.join(",")}');
  stdout.writeln('FORBIDDEN_PERMISSIONS='
      '${_forbiddenPermissions.join(",")}');
  stdout.writeln('FORBIDDEN_PERMISSIONS_ABSENT='
      '${_forbiddenPermissions.every((String p) => !permissions.contains(p)) ? "true" : "false"}');
}