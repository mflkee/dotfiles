#!/usr/bin/env node
// sync-ops-mcp — MCP server: Syncthing (REST) + dsync (CLI).
// Локальный Syncthing: API key автоматически читается из config.xml
// (переопределяется через SYNCTHING_API_KEY), адрес — SYNCTHING_URL
// (по умолчанию http://127.0.0.1:8384). dsync берётся из ~/.local/bin/dsync.
const { execFile } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
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

const headers = { 'X-API-Key': API_KEY, 'Content-Type': 'application/json', Accept: 'application/json' };

async function st(pathname, opts = {}) {
  const res = await fetch(`${SYNCTHING_URL}${pathname}`, { headers, ...opts });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Syncthing ${opts.method || 'GET'} ${pathname} → ${res.status}: ${text.slice(0, 300)}`);
  }
  if (res.status === 204) return null;
  const text = await res.text();
  if (!text.trim()) return null; // PUT/DELETE/scan отвечают пустым телом
  return JSON.parse(text);
}

function runDsync(args) {
  const bin = fs.existsSync(path.join(os.homedir(), '.local/bin/dsync'))
    ? path.join(os.homedir(), '.local/bin/dsync')
    : 'dsync';
  return new Promise((resolve, reject) => {
    execFile(bin, args, { timeout: 120000, maxBuffer: 4 * 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) {
        reject(new Error(`dsync ${args.join(' ')} failed: ${err.message}\n${stderr || stdout}`));
      } else {
        resolve(stdout || stderr);
      }
    });
  });
}

// Помощники Syncthing -------------------------------------------------------

async function listFolderConfigs() {
  return st('/rest/config/folders');
}

async function getFolderConfig(id) {
  try {
    return await st(`/rest/config/folders/${encodeURIComponent(id)}`);
  } catch (e) {
    if (/No folder with given ID/.test(e.message)) return null;
    throw e;
  }
}

async function putFolderConfig(folder) {
  await st(`/rest/config/folders/${encodeURIComponent(folder.id)}`, {
    method: 'PUT',
    body: JSON.stringify(folder),
  });
  // GET сразу после PUT может вернуть пустое тело (конфиг применяется асинхронно) — ретраим.
  for (let i = 0; i < 5; i++) {
    const saved = await getFolderConfig(folder.id);
    if (saved) return saved;
    await new Promise(r => setTimeout(r, 200));
  }
  return folder; // fallback: вернуть то, что отправили
}

async function listDeviceConfigs() {
  return st('/rest/config/devices');
}

async function resolveDevices(refs) {
  if (!refs || refs.length === 0) return [];
  const devices = await listDeviceConfigs();
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

const TOOLS = [
  {
    name: 'st-status',
    description: 'Syncthing system status: version, myID, uptime, folders/devices count.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'st-list-folders',
    description: 'List all Syncthing folders: id, label, path, type, paused, shared device names.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'st-folder-status',
    description: 'Detailed sync state of one folder (files/bytes, needs, errors) + per-device completion %.',
    inputSchema: {
      type: 'object',
      properties: { folder: { type: 'string', description: 'Folder ID' } },
      required: ['folder'],
    },
  },
  {
    name: 'st-list-devices',
    description: 'List known Syncthing devices: deviceID, name, connected, address, paused.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'st-connections',
    description: 'Current connections: which devices are online, addresses, transfer counters.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'st-completion',
    description: 'Completion % of a folder for each shared device (optionally one deviceID).',
    inputSchema: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder ID' },
        device: { type: 'string', description: 'Device ID (optional; default: all shared devices)' },
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
      },
      required: ['label', 'path'],
    },
  },
  {
    name: 'st-update-folder',
    description: 'Edit an existing folder: rename label, change path/type, pause/resume, change shared devices.',
    inputSchema: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder ID to edit' },
        label: { type: 'string', description: 'New label' },
        path: { type: 'string', description: 'New path' },
        type: { type: 'string', enum: ['sendreceive', 'sendonly', 'receiveonly', 'receiveencrypted'] },
        paused: { type: 'boolean', description: 'Pause (true) / resume (false)' },
        shareWith: { type: 'array', items: { type: 'string' }, description: 'Full replacement list of shared devices (names/IDs)' },
      },
      required: ['folder'],
    },
  },
  {
    name: 'st-remove-folder',
    description: 'Remove a folder from Syncthing config. Files on disk are NOT deleted. Safety: requires confirm="yes"; pausing first is recommended to avoid deletion propagation.',
    inputSchema: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder ID' },
        confirm: { type: 'string', description: 'Must be "yes" to proceed' },
      },
      required: ['folder', 'confirm'],
    },
  },
  {
    name: 'st-pause-folder',
    description: 'Pause a folder (stops sync and prevents propagation of local changes).',
    inputSchema: {
      type: 'object',
      properties: { folder: { type: 'string', description: 'Folder ID' } },
      required: ['folder'],
    },
  },
  {
    name: 'st-resume-folder',
    description: 'Resume a paused folder.',
    inputSchema: {
      type: 'object',
      properties: { folder: { type: 'string', description: 'Folder ID' } },
      required: ['folder'],
    },
  },
  {
    name: 'st-scan',
    description: 'Trigger an immediate rescan of a folder (optional sub path).',
    inputSchema: {
      type: 'object',
      properties: {
        folder: { type: 'string', description: 'Folder ID' },
        sub: { type: 'string', description: 'Optional sub path to scan' },
      },
      required: ['folder'],
    },
  },
  {
    name: 'st-restart',
    description: 'Restart the Syncthing service. Requires confirm="yes".',
    inputSchema: {
      type: 'object',
      properties: { confirm: { type: 'string', description: 'Must be "yes"' } },
      required: ['confirm'],
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
    description: 'One call: Syncthing folders + connections + dsync status (для быстрой проверки синхронизации).',
    inputSchema: { type: 'object', properties: {} },
  },
];

async function handleToolCall(name, args) {
  switch (name) {
    case 'st-status': {
      const s = await st('/rest/system/status');
      return {
        myID: s.myID, version: s.version, uptimeSeconds: s.uptime,
        folders: s.folders, devices: s.devices, goroutines: s.goroutines,
        discoveryEnabled: s.discoveryEnabled,
      };
    }
    case 'st-list-folders': {
      const folders = await listFolderConfigs();
      const devices = await listDeviceConfigs();
      const nameOf = id => (devices.find(d => d.deviceID === id) || {}).name || id;
      return folders.map(f => ({
        id: f.id, label: f.label, path: f.path, type: f.type, paused: f.paused,
        devices: f.devices.map(d => nameOf(d.deviceID)),
      }));
    }
    case 'st-folder-status': {
      const folder = await getFolderConfig(args.folder);
      if (!folder) throw new Error(`Folder not found: ${args.folder}`);
      const status = await st(`/rest/db/status?folder=${encodeURIComponent(args.folder)}`);
      const completion = [];
      for (const d of folder.devices) {
        const c = await st(`/rest/db/completion?folder=${encodeURIComponent(args.folder)}&device=${encodeURIComponent(d.deviceID)}`);
        completion.push({ device: d.deviceID, completion: `${c.completion.toFixed(1)}%`, needBytes: c.needBytes });
      }
      return { id: folder.id, label: folder.label, path: folder.path, type: folder.type, paused: folder.paused, status, completion };
    }
    case 'st-list-devices': {
      const devices = await listDeviceConfigs();
      return devices.map(d => ({
        deviceID: d.deviceID, name: d.name, paused: d.paused,
        addresses: (d.addresses || []).length === 1 && d.addresses[0] === 'dynamic' ? [] : d.addresses,
      }));
    }
    case 'st-connections': {
      const c = await st('/rest/system/connections');
      return Object.entries(c.connections).map(([id, v]) => ({
        deviceID: id, connected: v.connected, address: v.address,
        inBytes: v.inBytesTotal, outBytes: v.outBytesTotal,
      }));
    }
    case 'st-completion': {
      const folder = await getFolderConfig(args.folder);
      if (!folder) throw new Error(`Folder not found: ${args.folder}`);
      const targets = args.device ? [args.device] : folder.devices.map(d => d.deviceID);
      const out = [];
      for (const dev of targets) {
        const c = await st(`/rest/db/completion?folder=${encodeURIComponent(args.folder)}&device=${encodeURIComponent(dev)}`);
        out.push({ device: dev, ...c });
      }
      return out;
    }
    case 'st-add-folder': {
      const id = args.id || genFolderId();
      if (await getFolderConfig(id)) throw new Error(`Folder already exists: ${id}`);
      const shareWith = await resolveDevices(args.shareWith);
      const folder = {
        id,
        label: args.label,
        path: args.path,
        type: args.type || 'sendreceive',
        devices: shareWith.map(deviceID => ({ deviceID, introducedBy: '', encryptionPassword: '' })),
      };
      const created = await putFolderConfig(folder);
      return {
        id: created.id, label: created.label, path: created.path, type: created.type,
        shares: created.devices.map(d => d.deviceID),
        hint: 'Папка создана локально. Чтобы ей делиться с другими узлами, добавь sharing на них или попроси принять pending offer.',
      };
    }
    case 'st-update-folder': {
      const cur = await getFolderConfig(args.folder);
      if (!cur) throw new Error(`Folder not found: ${args.folder}`);
      if (args.label !== undefined) cur.label = args.label;
      if (args.path !== undefined) cur.path = args.path;
      if (args.type !== undefined) cur.type = args.type;
      if (args.paused !== undefined) cur.paused = args.paused;
      if (args.shareWith !== undefined) {
        const ids = await resolveDevices(args.shareWith);
        cur.devices = ids.map(deviceID => ({ deviceID, introducedBy: '', encryptionPassword: '' }));
      }
      const updated = await putFolderConfig(cur);
      return { id: updated.id, label: updated.label, path: updated.path, type: updated.type, paused: updated.paused, devices: updated.devices.map(d => d.deviceID) };
    }
    case 'st-remove-folder': {
      if (args.confirm !== 'yes') throw new Error('Remove requires confirm="yes"');
      const cur = await getFolderConfig(args.folder);
      if (!cur) throw new Error(`Folder not found: ${args.folder}`);
      await st(`/rest/config/folders/${encodeURIComponent(args.folder)}`, { method: 'DELETE' });
      return { removed: args.folder, note: 'Конфиг удалён, файлы на диске не тронуты.' };
    }
    case 'st-pause-folder':
    case 'st-resume-folder': {
      const cur = await getFolderConfig(args.folder);
      if (!cur) throw new Error(`Folder not found: ${args.folder}`);
      cur.paused = name === 'st-pause-folder';
      const updated = await putFolderConfig(cur);
      return { id: updated.id, paused: updated.paused };
    }
    case 'st-scan': {
      let q = `/rest/db/scan?folder=${encodeURIComponent(args.folder)}`;
      if (args.sub) q += `&sub=${encodeURIComponent(args.sub)}`;
      await st(q, { method: 'POST' });
      return { scanned: args.folder, sub: args.sub || null };
    }
    case 'st-restart': {
      if (args.confirm !== 'yes') throw new Error('Restart requires confirm="yes"');
      await st('/rest/system/restart', { method: 'POST' });
      return { restarting: true };
    }
    case 'dsync-status': return { host: hostnameName(), output: (await runDsync(['status'])).trim() };
    case 'dsync-doctor': return { host: hostnameName(), output: (await runDsync(['doctor'])).trim() };
    case 'dsync-push': return { pushed: args.machine || 'all', output: (await runDsync(['push', ...(args.machine ? [args.machine] : [])])).trim() };
    case 'dsync-pull': return { pulled: args.machine || 'all', output: (await runDsync(['pull', ...(args.machine ? [args.machine] : [])])).trim() };
    case 'overview': {
      const [status, folders, connections, dsync] = await Promise.all([
        st('/rest/system/status'),
        st('/rest/config/folders'),
        st('/rest/system/connections'),
        runDsync(['status']).catch(e => `dsync error: ${e.message}`),
      ]);
      const devices = await st('/rest/config/devices');
      const nameOf = id => (devices.find(d => d.deviceID === id) || {}).name || id;
      return {
        syncthing: {
          version: status.version,
          folders: folders.map(f => ({
            id: f.id, label: f.label, path: f.path, type: f.type, paused: f.paused,
            shared: f.devices.map(d => nameOf(d.deviceID)),
          })),
          connected: Object.entries(connections.connections).filter(([, v]) => v.connected).map(([id]) => nameOf(id)),
        },
        dsync: { host: hostnameName(), status: dsync.trim().slice(-3000) },
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