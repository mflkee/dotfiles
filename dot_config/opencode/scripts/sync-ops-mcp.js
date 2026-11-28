#!/usr/bin/env node
// sync-ops-mcp — MCP server: Syncthing (REST) + dsync (CLI).
// Локальный Syncthing: API key автоматически читается из config.xml
// (переопределяется через SYNCTHING_API_KEY), адрес — SYNCTHING_URL
// (по умолчанию http://127.0.0.1:8384). dsync берётся из ~/.local/bin/dsync.
//
// Удалённые Syncthing-хосты (Windows/Linux) описываются в
// ~/.config/opencode/sync-ops-hosts.json. Транспорт — SSH-туннель
// (ssh -N -L <local>:127.0.0.1:8384 <target>), API key читается из
// config.xml на самом хосте по SSH (или берётся из apiKey).
const { execFile, spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const crypto = require('node:crypto');

const SYNCTHING_URL = process.env.SYNCTHING_URL || 'http://127.0.0.1:8384';

function readApiKey() {
  if (process.env.SYNCTHING_API_KEY) return process.env.SYNCTHING_API_KEY;
  const candidates = [
    path.join(os.homedir(), '.local/state/syncthing/config.xml'),
    path.join(os.homedir(), '.config/syncthing/config.xml'),
  ];
  for (const f of candidates) {
    try {
      const xml = fs.readFileSync(f, 'utf8');
      const m = xml.match(/<apikey>([^<]+)<\/apikey>/);
      if (m && m[1]) return m[1];
    } catch (_) { /* next */ }
  }
  return null;
}

const API_KEY = readApiKey();
if (!API_KEY) {
  console.error('sync-ops-mcp: Syncthing API key not found (checked env + config.xml)');
  process.exit(1);
}

// Хосты ---------------------------------------------------------------------

const HOSTS_FILE = process.env.SYNCTHING_HOSTS
  || path.join(os.homedir(), '.config/opencode/sync-ops-hosts.json');
let HOSTS = {};
let HOSTS_ERROR = null;
try {
  HOSTS = JSON.parse(fs.readFileSync(HOSTS_FILE, 'utf8'));
} catch (e) {
  if (e.code !== 'ENOENT') HOSTS_ERROR = e.message;
}

function expandHome(p) {
  if (!p) return p;
  if (p === '~') return os.homedir();
  if (p.startsWith('~/')) return path.join(os.homedir(), p.slice(2));
  return p;
}

function hostConfig(name) {
  if (!name || name === 'local') return null;
  const h = HOSTS[name];
  if (!h) {
    const known = ['local', ...Object.keys(HOSTS)].join(', ');
    throw new Error(`Unknown host "${name}". Known: ${known}. Config: ${HOSTS_FILE}${HOSTS_ERROR ? ` (${HOSTS_ERROR})` : ''}`);
  }
  return h;
}

function sshArgs(host) {
  const args = [
    '-o', 'BatchMode=yes',
    '-o', 'StrictHostKeyChecking=accept-new',
    '-o', 'ConnectTimeout=10',
  ];
  if (host.key) args.push('-i', expandHome(host.key), '-o', 'IdentitiesOnly=yes');
  return args;
}

function sshExec(host, command, timeout = 30000) {
  return new Promise((resolve, reject) => {
    execFile('ssh', [...sshArgs(host), host.ssh, command], {
      timeout,
      maxBuffer: 4 * 1024 * 1024,
    }, (err, stdout, stderr) => {
      if (err) {
        const extra = (stderr || '').trim().slice(0, 500);
        reject(new Error(`ssh ${host.ssh} failed: ${err.message}${extra ? `\n${extra}` : ''}`));
      } else {
        resolve(stdout);
      }
    });
  });
}

const tunnels = new Map(); // hostName -> { proc, port }
const baseCache = new Map(); // hostName -> http://127.0.0.1:port
const keyCache = new Map(); // hostName -> api key

function freePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.once('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
  });
}

function waitPort(port, timeoutMs = 12000) {
  const started = Date.now();
  return new Promise((resolve, reject) => {
    const attempt = () => {
      const sock = net.connect({ host: '127.0.0.1', port });
      sock.once('connect', () => { sock.destroy(); resolve(); });
      sock.once('error', () => {
        sock.destroy();
        if (Date.now() - started > timeoutMs) {
          reject(new Error(`SSH tunnel did not open 127.0.0.1:${port} in ${timeoutMs} ms`));
        } else {
          setTimeout(attempt, 200);
        }
      });
    };
    attempt();
  });
}

async function ensureTunnel(name, host) {
  const existing = tunnels.get(name);
  if (existing && existing.proc.exitCode === null) return existing;

  const [rhost, rportRaw] = String(host.remoteApi || '127.0.0.1:8384').split(':');
  const rport = Number(rportRaw || 8384);
  const localPort = Number(host.localPort) || await freePort();
  const args = [
    ...sshArgs(host),
    '-N',
    '-o', 'ExitOnForwardFailure=yes',
    '-o', 'ServerAliveInterval=30',
    '-o', 'ServerAliveCountMax=3',
    '-L', `127.0.0.1:${localPort}:${rhost}:${rport}`,
    host.ssh,
  ];

  const proc = spawn('ssh', args, { stdio: ['ignore', 'ignore', 'pipe'] });
  let stderr = '';
  proc.stderr.on('data', d => { stderr += d.toString(); });
  proc.once('exit', () => {
    tunnels.delete(name);
    baseCache.delete(name);
  });
  tunnels.set(name, { proc, port: localPort });

  try {
    await waitPort(localPort);
  } catch (e) {
    try { proc.kill(); } catch (_) { /* ignore */ }
    tunnels.delete(name);
    throw new Error(`${e.message}${stderr ? ` (ssh: ${stderr.trim().slice(0, 300)})` : ''}`);
  }
  return { proc, port: localPort };
}

async function apiKeyFor(name, host) {
  if (host.apiKey) return host.apiKey;
  if (keyCache.has(name)) return keyCache.get(name);
  if (!host.apiKeyPath) throw new Error(`Host "${name}" has no apiKey/apiKeyPath in ${HOSTS_FILE}`);
  const command = host.os === 'windows'
    ? `type "${host.apiKeyPath}"`
    : `cat ${host.apiKeyPath}`;
  const xml = await sshExec(host, command);
  const m = xml.match(/<apikey>([^<]+)<\/apikey>/);
  if (!m) throw new Error(`No <apikey> in ${host.apiKeyPath} on "${name}"`);
  keyCache.set(name, m[1]);
  return m[1];
}

async function apiBase(name) {
  if (!name || name === 'local') return SYNCTHING_URL;
  const host = hostConfig(name);
  if (host.apiUrl) return host.apiUrl.replace(/\/$/, '');
  if (baseCache.has(name)) {
    const t = tunnels.get(name);
    if (t && t.proc.exitCode === null) return baseCache.get(name);
    baseCache.delete(name);
  }
  const { port } = await ensureTunnel(name, host);
  const base = `http://127.0.0.1:${port}`;
  baseCache.set(name, base);
  return base;
}

async function st(pathname, opts = {}, hostName = 'local') {
  const host = hostConfig(hostName);
  const [baseUrl, apiKey] = await Promise.all([
    apiBase(hostName),
    host ? apiKeyFor(hostName, host) : Promise.resolve(API_KEY),
  ]);
  const headers = { 'X-API-Key': apiKey, 'Content-Type': 'application/json', Accept: 'application/json' };
  const res = await fetch(`${baseUrl}${pathname}`, { headers, ...opts });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Syncthing[${hostName}] ${opts.method || 'GET'} ${pathname} → ${res.status}: ${text.slice(0, 300)}`);
  }
  if (res.status === 204) return null;
  const text = await res.text();
  if (!text.trim()) return null; // PUT/DELETE/scan отвечают пустым телом
  return JSON.parse(text);
}

process.on('exit', () => {
  for (const { proc } of tunnels.values()) {
    try { proc.kill(); } catch (_) { /* ignore */ }
  }
});

// dsync пишет цветной лог (tracing) в stdout даже не в TTY. В ответе MCP
// ANSI-последовательности — мусор для модели, поэтому гасим их на источнике
// (NO_COLOR/TERM=dumb) и подчищаем на выходе, если dsync их всё же выдал.
const ANSI_RE = /\x1B\[[0-9;?]*[ -/]*[@-~]/g;
function stripAnsi(s) {
  return (s || '').replace(ANSI_RE, '');
}

function runDsync(args) {
  const bin = fs.existsSync(path.join(os.homedir(), '.local/bin/dsync'))
    ? path.join(os.homedir(), '.local/bin/dsync')
    : 'dsync';
  return new Promise((resolve, reject) => {
    execFile(bin, args, {
      timeout: 120000,
      maxBuffer: 4 * 1024 * 1024,
      env: { ...process.env, NO_COLOR: '1', TERM: 'dumb', CLICOLOR: '0' },
    }, (err, stdout, stderr) => {
      if (err) {
        reject(new Error(`dsync ${args.join(' ')} failed: ${err.message}\n${stripAnsi(stderr || stdout)}`));
      } else {
        resolve(stripAnsi(stdout || stderr));
      }
    });
  });
}

// Помощники Syncthing -------------------------------------------------------

async function listFolderConfigs(host = 'local') {
  return st('/rest/config/folders', {}, host);
}

async function getFolderConfig(id, host = 'local') {
  try {
    return await st(`/rest/config/folders/${encodeURIComponent(id)}`, {}, host);
  } catch (e) {
    if (/No folder with given ID/.test(e.message)) return null;
    throw e;
  }
}

async function putFolderConfig(folder, host = 'local') {
  await st(`/rest/config/folders/${encodeURIComponent(folder.id)}`, {
    method: 'PUT',
    body: JSON.stringify(folder),
  }, host);
  // GET сразу после PUT может вернуть пустое тело (конфиг применяется асинхронно) — ретраим.
  for (let i = 0; i < 5; i++) {
    const saved = await getFolderConfig(folder.id, host);
    if (saved) return saved;
    await new Promise(r => setTimeout(r, 200));
  }
  return folder; // fallback: вернуть то, что отправили
}

async function listDeviceConfigs(host = 'local') {
  return st('/rest/config/devices', {}, host);
}

async function resolveDevices(refs, host = 'local') {
  if (!refs || refs.length === 0) return [];
  const devices = await listDeviceConfigs(host);
  const byId = new Map();
  const byName = new Map();
  for (const d of devices) {
    byId.set(d.deviceID, d);
    if (d.name) byName.set(d.name.toLowerCase(), d);
  }
  const out = [];
  for (const ref of refs) {
    const d = byId.get(ref) || byName.get(String(ref).toLowerCase());
    if (!d) throw new Error(`Device not found: ${ref} (knows: ${devices.map(x => x.name || x.deviceID).join(', ')})`);
    out.push(d.deviceID);
  }
  return out;
}

function genFolderId() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  const pick = n => Array.from({ length: n }, () => alphabet[crypto.randomInt(alphabet.length)]).join('');
  return `${pick(5)}-${pick(4)}`;
}

function hostnameName() {
  return os.hostname();
}

// Обработчики тулов ---------------------------------------------------------

const HOST_PROP = {
  type: 'string',
  description: 'Remote host name from sync-ops-hosts.json (default: local)',
};

const TOOLS = [
  {
    name: 'st-status',
    description: 'Syncthing system status: version, myID, uptime, folders/devices count. Use host for remote.',
    inputSchema: { type: 'object', properties: { host: HOST_PROP } },
  },
  {
    name: 'st-list-folders',
    description: 'List all Syncthing folders: id, label, path, type, paused, shared device names. Use host for remote.',
    inputSchema: { type: 'object', properties: { host: HOST_PROP } },
  },
  {
    name: 'st-folder-status',
    description: 'Detailed sync state of one folder (files/bytes, needs, errors) + per-device completion %. Use host for remote.',
    inputSchema: {
      type: 'object',
      properties: { folder: { type: 'string', description: 'Folder ID' }, host: HOST_PROP },
      required: ['folder'],
    },
  },
  {
    name: 'st-list-devices',
    description: 'List known Syncthing devices: deviceID, name, connected, address, paused. Use host for remote.',
    inputSchema: { type: 'object', properties: { host: HOST_PROP } },
  },
  {
    name: 'st-connections',
    description: 'Current connections: which devices are online, addresses, transfer counters. Use host for remote.',
    inputSchema: { type: 'object', properties: { host: HOST_PROP } },
  },
  {
    name: 'st-completion',
    description: 'Completion % of a folder for each shared device (optionally one deviceID). Use host for remote.',
    inputSchema: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder ID' },
        device: { type: 'string', description: 'Device ID (optional; default: all shared devices)' },
        host: HOST_PROP,
      },
      required: ['folder'],
    },
  },
  {
    name: 'st-add-folder',
    description: 'Create a new Syncthing folder. id auto-generated if omitted. shareWith accepts device names or IDs.',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string', description: 'Folder ID (kebab/random; auto if omitted)' },
        label: { type: 'string', description: 'Human label, e.g. "obs_main"' },
        path: { type: 'string', description: 'Absolute local path to sync' },
        type: { type: 'string', enum: ['sendreceive', 'sendonly', 'receiveonly', 'receiveencrypted'], description: 'Default sendreceive' },
        shareWith: { type: 'array', items: { type: 'string' }, description: 'Device names/IDs to share with (default: local only)' },
        host: HOST_PROP,
      },
      required: ['label', 'path'],
    },
  },
  {
    name: 'st-update-folder',
    description: 'Edit an existing folder: rename label, change path/type, pause/resume, change shared devices. Use host for remote.',
    inputSchema: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder ID to edit' },
        label: { type: 'string', description: 'New label' },
        path: { type: 'string', description: 'New path (on the target host)' },
        type: { type: 'string', enum: ['sendreceive', 'sendonly', 'receiveonly', 'receiveencrypted'] },
        paused: { type: 'boolean', description: 'Pause (true) / resume (false)' },
        shareWith: { type: 'array', items: { type: 'string' }, description: 'Full replacement list of shared devices (names/IDs)' },
        host: HOST_PROP,
      },
      required: ['folder'],
    },
  },
  {
    name: 'st-remove-folder',
    description: 'Remove a folder from Syncthing config. Files on disk are NOT deleted. Safety: requires confirm="yes"; pausing first is recommended to avoid deletion propagation. Use host for remote.',
    inputSchema: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder ID' },
        confirm: { type: 'string', description: 'Must be "yes" to proceed' },
        host: HOST_PROP,
      },
      required: ['folder', 'confirm'],
    },
  },
  {
    name: 'st-pause-folder',
    description: 'Pause a folder (stops sync and prevents propagation of local changes). Use host for remote.',
    inputSchema: {
      type: 'object',
      properties: { folder: { type: 'string', description: 'Folder ID' }, host: HOST_PROP },
      required: ['folder'],
    },
  },
  {
    name: 'st-resume-folder',
    description: 'Resume a paused folder. Use host for remote.',
    inputSchema: {
      type: 'object',
      properties: { folder: { type: 'string', description: 'Folder ID' }, host: HOST_PROP },
      required: ['folder'],
    },
  },
  {
    name: 'st-scan',
    description: 'Trigger an immediate rescan of a folder (optional sub path). Use host for remote.',
    inputSchema: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder ID' },
        sub: { type: 'string', description: 'Optional sub path to scan' },
        host: HOST_PROP,
      },
      required: ['folder'],
    },
  },
  {
    name: 'st-restart',
    description: 'Restart the Syncthing process. Requires confirm="yes". Use host for remote.',
    inputSchema: {
      type: 'object',
      properties: { confirm: { type: 'string', description: 'Must be "yes"' }, host: HOST_PROP },
      required: ['confirm'],
    },
  },
  {
    name: 'st-hosts',
    description: 'List configured Syncthing hosts (local + remote from sync-ops-hosts.json) with reachability, version and SSH target.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'st-health',
    description: 'Quick sync health for a folder: state, needs, errors, per-device completion, online status, warnings. Default folder: sikn1520.',
    inputSchema: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder ID (default: sikn1520)' },
        host: HOST_PROP,
      },
    },
  },
  {
    name: 'dsync-status',
    description: 'dsync status — здоровье hub/машин (что синхронизировано, кто онлайн).',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'dsync-doctor',
    description: 'dsync doctor — диагностика конфигурации/подключений.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'dsync-push',
    description: 'Push local state (zen + projects) to dsync hub.',
    inputSchema: {
      type: 'object',
      properties: { machine: { type: 'string', description: 'Target machine name (default: all)' } },
    },
  },
  {
    name: 'dsync-pull',
    description: 'Pull state from dsync hub.',
    inputSchema: {
      type: 'object',
      properties: { machine: { type: 'string', description: 'Source machine name (default: all)' } },
    },
  },
  {
    name: 'overview',
    description: 'One call: Syncthing folders + connections + dsync status (для быстрой проверки синхронизации). host — удалённый узел.',
    inputSchema: { type: 'object', properties: { host: HOST_PROP } },
  },
];

async function handleToolCall(name, args) {
  const host = args.host || 'local';
  switch (name) {
    case 'st-status': {
      // Syncthing v2 убрал version/folders/devices из /rest/system/status —
      // версия живёт в /rest/system/version, счётчики считаем по конфигу.
      const [s, v, folders, devices] = await Promise.all([
        st('/rest/system/status', {}, host),
        st('/rest/system/version', {}, host).catch(() => null),
        listFolderConfigs(host),
        listDeviceConfigs(host),
      ]);
      return {
        host,
        myID: s.myID, version: v ? v.version : null,
        uptimeSeconds: s.uptime,
        folderCount: folders.length, deviceCount: devices.length,
        goroutines: s.goroutines,
        discoveryEnabled: s.discoveryEnabled,
      };
    }
    case 'st-list-folders': {
      const folders = await listFolderConfigs(host);
      const devices = await listDeviceConfigs(host);
      const nameOf = id => (devices.find(d => d.deviceID === id) || {}).name || id;
      return folders.map(f => ({
        id: f.id, label: f.label, path: f.path, type: f.type, paused: f.paused,
        devices: f.devices.map(d => nameOf(d.deviceID)),
      }));
    }
    case 'st-folder-status': {
      const folder = await getFolderConfig(args.folder, host);
      if (!folder) throw new Error(`Folder not found: ${args.folder}`);
      const status = await st(`/rest/db/status?folder=${encodeURIComponent(args.folder)}`, {}, host);
      const completion = [];
      for (const d of folder.devices) {
        const c = await st(`/rest/db/completion?folder=${encodeURIComponent(args.folder)}&device=${encodeURIComponent(d.deviceID)}`, {}, host);
        completion.push({ device: d.deviceID, completion: `${c.completion.toFixed(1)}%`, needBytes: c.needBytes });
      }
      return { host, id: folder.id, label: folder.label, path: folder.path, type: folder.type, paused: folder.paused, status, completion };
    }
    case 'st-list-devices': {
      const devices = await listDeviceConfigs(host);
      return devices.map(d => ({
        deviceID: d.deviceID, name: d.name, paused: d.paused,
        addresses: (d.addresses || []).length === 1 && d.addresses[0] === 'dynamic' ? [] : d.addresses,
      }));
    }
    case 'st-connections': {
      const c = await st('/rest/system/connections', {}, host);
      return Object.entries(c.connections).map(([id, v]) => ({
        deviceID: id, connected: v.connected, address: v.address,
        inBytes: v.inBytesTotal, outBytes: v.outBytesTotal,
      }));
    }
    case 'st-completion': {
      const folder = await getFolderConfig(args.folder, host);
      if (!folder) throw new Error(`Folder not found: ${args.folder}`);
      const targets = args.device ? [args.device] : folder.devices.map(d => d.deviceID);
      const out = [];
      for (const dev of targets) {
        const c = await st(`/rest/db/completion?folder=${encodeURIComponent(args.folder)}&device=${encodeURIComponent(dev)}`, {}, host);
        out.push({ device: dev, ...c });
      }
      return out;
    }
    case 'st-add-folder': {
      const id = args.id || genFolderId();
      if (await getFolderConfig(id, host)) throw new Error(`Folder already exists: ${id}`);
      const shareWith = await resolveDevices(args.shareWith, host);
      const folder = {
        id,
        label: args.label,
        path: args.path,
        type: args.type || 'sendreceive',
        devices: shareWith.map(deviceID => ({ deviceID, introducedBy: '', encryptionPassword: '' })),
      };
      const created = await putFolderConfig(folder, host);
      return {
        host, id: created.id, label: created.label, path: created.path, type: created.type,
        shares: created.devices.map(d => d.deviceID),
        hint: 'Папка создана. Чтобы делиться с другими узлами, добавь sharing на них или прими pending offer.',
      };
    }
    case 'st-update-folder': {
      const cur = await getFolderConfig(args.folder, host);
      if (!cur) throw new Error(`Folder not found: ${args.folder}`);
      if (args.label !== undefined) cur.label = args.label;
      if (args.path !== undefined) cur.path = args.path;
      if (args.type !== undefined) cur.type = args.type;
      if (args.paused !== undefined) cur.paused = args.paused;
      if (args.shareWith !== undefined) {
        const ids = await resolveDevices(args.shareWith, host);
        cur.devices = ids.map(deviceID => ({ deviceID, introducedBy: '', encryptionPassword: '' }));
      }
      const updated = await putFolderConfig(cur, host);
      return { host, id: updated.id, label: updated.label, path: updated.path, type: updated.type, paused: updated.paused, devices: updated.devices.map(d => d.deviceID) };
    }
    case 'st-remove-folder': {
      if (args.confirm !== 'yes') throw new Error('Remove requires confirm="yes"');
      const cur = await getFolderConfig(args.folder, host);
      if (!cur) throw new Error(`Folder not found: ${args.folder}`);
      await st(`/rest/config/folders/${encodeURIComponent(args.folder)}`, { method: 'DELETE' }, host);
      return { host, removed: args.folder, note: 'Конфиг удалён, файлы на диске не тронуты.' };
    }
    case 'st-pause-folder':
    case 'st-resume-folder': {
      const cur = await getFolderConfig(args.folder, host);
      if (!cur) throw new Error(`Folder not found: ${args.folder}`);
      cur.paused = name === 'st-pause-folder';
      const updated = await putFolderConfig(cur, host);
      return { host, id: updated.id, paused: updated.paused };
    }
    case 'st-scan': {
      let q = `/rest/db/scan?folder=${encodeURIComponent(args.folder)}`;
      if (args.sub) q += `&sub=${encodeURIComponent(args.sub)}`;
      await st(q, { method: 'POST' }, host);
      return { host, scanned: args.folder, sub: args.sub || null };
    }
    case 'st-restart': {
      if (args.confirm !== 'yes') throw new Error('Restart requires confirm="yes"');
      await st('/rest/system/restart', { method: 'POST' }, host);
      return { host, restarting: true };
    }
    case 'st-hosts': {
      const names = ['local', ...Object.keys(HOSTS)];
      return Promise.all(names.map(async n => {
        const cfg = n === 'local' ? null : HOSTS[n];
        try {
          const [s, v] = await Promise.all([
            st('/rest/system/status', {}, n),
            st('/rest/system/version', {}, n).catch(() => null),
          ]);
          return { host: n, ok: true, myID: s.myID, version: v ? v.version : null, ssh: cfg ? cfg.ssh : null };
        } catch (e) {
          return { host: n, ok: false, ssh: cfg ? cfg.ssh : null, error: e.message };
        }
      }));
    }
    case 'st-health': {
      const folderId = args.folder || 'sikn1520';
      const [folder, status, conns, devices, sys] = await Promise.all([
        getFolderConfig(folderId, host),
        st(`/rest/db/status?folder=${encodeURIComponent(folderId)}`, {}, host),
        st('/rest/system/connections', {}, host),
        listDeviceConfigs(host),
        st('/rest/system/status', {}, host),
      ]);
      if (!folder) throw new Error(`Folder not found: ${folderId}`);
      const nameOf = id => (devices.find(d => d.deviceID === id) || {}).name || id;
      const myID = sys.myID;
      const completion = [];
      for (const d of folder.devices) {
        const c = await st(`/rest/db/completion?folder=${encodeURIComponent(folderId)}&device=${encodeURIComponent(d.deviceID)}`, {}, host);
        const conn = conns.connections[d.deviceID] || {};
        const isLocal = d.deviceID === myID;
        completion.push({
          device: nameOf(d.deviceID),
          deviceID: d.deviceID,
          connected: isLocal ? true : !!conn.connected,
          address: isLocal ? 'local' : (conn.address || ''),
          completion: Number(c.completion.toFixed(1)),
          needBytes: c.needBytes,
          needItems: c.needItems,
          needDeletes: c.needDeletes,
        });
      }
      const warnings = [];
      if (status.state !== 'idle') warnings.push(`state: ${status.state}`);
      if (status.errors > 0) warnings.push(`errors: ${status.errors}`);
      if (status.pullErrors > 0) warnings.push(`pullErrors: ${status.pullErrors}`);
      if (status.needFiles > 0 || status.needBytes > 0) warnings.push(`needs ${status.needFiles} files / ${status.needBytes} B`);
      if (status.needDeletes > 0) warnings.push(`needs ${status.needDeletes} deletes`);
      for (const c of completion) {
        if (c.deviceID === myID) continue;
        if (!c.connected) warnings.push(`${c.device}: offline`);
        else if (c.completion < 100 || c.needBytes > 0) warnings.push(`${c.device}: ${c.completion}% (need ${c.needBytes} B)`);
      }
      return {
        host,
        folder: folderId, label: folder.label, path: folder.path, type: folder.type, paused: folder.paused,
        state: status.state,
        needFiles: status.needFiles, needBytes: status.needBytes, needDeletes: status.needDeletes,
        errors: status.errors, pullErrors: status.pullErrors,
        completion, warnings,
      };
    }
    case 'dsync-status': return { host: hostnameName(), output: (await runDsync(['status'])).trim() };
    case 'dsync-doctor': return { host: hostnameName(), output: (await runDsync(['doctor'])).trim() };
    case 'dsync-push': return { pushed: args.machine || 'all', output: (await runDsync(['push', ...(args.machine ? [args.machine] : [])])).trim() };
    case 'dsync-pull': return { pulled: args.machine || 'all', output: (await runDsync(['pull', ...(args.machine ? [args.machine] : [])])).trim() };
    case 'overview': {
      const [version, folders, connections] = await Promise.all([
        st('/rest/system/version', {}, host).catch(() => null),
        st('/rest/config/folders', {}, host),
        st('/rest/system/connections', {}, host),
      ]);
      const devices = await st('/rest/config/devices', {}, host);
      const nameOf = id => (devices.find(d => d.deviceID === id) || {}).name || id;
      const dsync = host === 'local'
        ? { host: hostnameName(), status: (await runDsync(['status']).catch(e => `dsync error: ${e.message}`)).trim().slice(-3000) }
        : { skipped: `remote host ${host}` };
      return {
        host,
        syncthing: {
          version: version ? version.version : null,
          folders: folders.map(f => ({
            id: f.id, label: f.label, path: f.path, type: f.type, paused: f.paused,
            shared: f.devices.map(d => nameOf(d.deviceID)),
          })),
          connected: Object.entries(connections.connections).filter(([, v]) => v.connected).map(([id]) => nameOf(id)),
        },
        dsync,
      };
    }
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

// MCP stdio transport (тот же паттерн, что netbird-mcp.js) -------------------
const buf = [];
process.stdin.on('data', chunk => {
  buf.push(chunk);
  const text = buf.join('');
  const lines = text.split('\n');
  buf.length = 0;
  buf.push(lines.pop());

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      handleRequest(JSON.parse(trimmed));
    } catch (e) {
      // ignore parse errors
    }
  }
});

async function handleRequest(req) {
  const send = result => {
    process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: req.id, result }) + '\n');
  };
  const sendError = (code, message) => {
    process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: req.id, error: { code, message } }) + '\n');
  };

  try {
    switch (req.method) {
      case 'initialize':
        send({
          protocolVersion: '2024-11-05',
          capabilities: { tools: {} },
          serverInfo: { name: 'sync-ops-mcp', version: '1.0.0' },
        });
        break;
      case 'notifications/initialized':
        break;
      case 'tools/list':
        send({ tools: TOOLS });
        break;
      case 'tools/call': {
        const result = await handleToolCall(req.params.name, req.params.arguments || {});
        send({ content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] });
        break;
      }
      default:
        sendError(-32601, `Method not found: ${req.method}`);
    }
  } catch (e) {
    sendError(-32603, e.message);
  }
}