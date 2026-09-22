import { existsSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Match the SDK used by pubspec.lock; never build against a moving stable branch.
const flutterVersion = '3.47.2';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sdk = process.env.FLUTTER_ROOT || join(root, '.vercel', 'cache', `flutter-${flutterVersion}`);

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: root, stdio: 'inherit', ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Build command failed (${result.status}).`);
}

try {
  const value = process.env.API_BASE_URL;
  if (!value) throw new Error('Configure API_BASE_URL na Vercel: https://SUA-API.vercel.app/api/v1');
  const api = new URL(value);
  if (api.protocol !== 'https:' || api.username || api.password || api.search || api.hash ||
      api.pathname.replace(/\/+$/, '') !== '/api/v1') {
    throw new Error('API_BASE_URL deve ser uma URL HTTPS pública terminada em /api/v1, sem credenciais.');
  }
  const baseUrl = api.href.replace(/\/+$/, '');
  const sdkGit = spawnSync('git', ['--git-dir', join(sdk, '.git'), 'cat-file', '-e', 'HEAD^{commit}'],
    { encoding: 'utf8' });
  if (!existsSync(join(sdk, 'bin', 'flutter')) || sdkGit.status !== 0) {
    if (process.env.FLUTTER_ROOT) throw new Error('FLUTTER_ROOT deve conter um SDK Flutter com os metadados Git.');
    // Vercel can restore an empty/incomplete .git directory; validate its HEAD.
    // Only clear our managed SDK directory, never a user-provided FLUTTER_ROOT.
    rmSync(sdk, { recursive: true, force: true });
    mkdirSync(dirname(sdk), { recursive: true });
    run('git', ['clone', '--depth', '1', '--branch', flutterVersion,
      'https://github.com/flutter/flutter.git', sdk]);
  }
  const windows = process.platform === 'win32';
  const executable = windows ? join(sdk, 'bin', 'cache', 'dart-sdk', 'bin', 'dart.exe') : join(sdk, 'bin', 'flutter');
  const prefix = windows ? [join(sdk, 'bin', 'cache', 'flutter_tools.snapshot')] : [];
  run(executable, [...prefix, 'config', '--no-analytics']);
  run(executable, [...prefix, 'pub', 'get', '--enforce-lockfile']);
  run(executable, [...prefix, 'build', 'web', '--release', '--no-pub', `--dart-define=API_BASE_URL=${baseUrl}`]);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
