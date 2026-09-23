#!/usr/bin/env node
const NETBIRD_API = process.env.NETBIRD_API_URL || 'https://api.netbird.io';
const TOKEN = process.env.NETBIRD_API_KEY;

if (!TOKEN) {
  console.error('NETBIRD_API_KEY env var required');
  process.exit(1);
}

const headers = { Authorization: `Token ${TOKEN}`, 'Content-Type': 'application/json' };

async function api(path, opts = {}) {
  const res = await fetch(`${NETBIRD_API}${path}`, { headers, ...opts });
  if (!res.ok) throw new Error(`NetBird API ${res.status}: ${await res.text()}`);
  return res.json();
}

const TOOLS = [
  {
    name: 'list-peers',
    description: 'List all peers in the NetBird network. Optionally filter by name or IP.',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Filter by peer name (partial match)' },
        ip: { type: 'string', description: 'Filter by NetBird IP address' },
      },
    },
  },
  {
    name: 'rename-peer',
    description: 'Rename a peer. Provide either peerId or current name + newName.',
    inputSchema: {
      type: 'object',
      properties: {
        peerId: { type: 'string', description: 'Peer ID (if known)' },
        currentName: { type: 'string', description: 'Current peer name (used to look up ID if peerId not provided)' },
        newName: { type: 'string', description: 'New name for the peer' },
      },
      required: ['newName'],
    },
  },
  {
    name: 'get-peer',
    description: 'Get detailed info about a peer by ID or name.',
    inputSchema: {
      type: 'object',
      properties: {
        peerId: { type: 'string', description: 'Peer ID' },
        name: { type: 'string', description: 'Peer name (looks up by name)' },
      },
    },
  },
  {
    name: 'get-peer-by-ip',
    description: 'Find a peer by its NetBird IP address.',
    inputSchema: {
      type: 'object',
      properties: {
        ip: { type: 'string', description: 'NetBird IP address (e.g. 100.89.126.211)' },
      },
      required: ['ip'],
    },
  },
];

async function findPeerId(name) {
  const peers = await api(`/api/peers?name=${encodeURIComponent(name)}`);
  if (peers.length === 0) throw new Error(`No peer found with name "${name}"`);
  if (peers.length > 1) throw new Error(`Multiple peers match "${name}": ${peers.map(p => p.name).join(', ')}`);
  return peers[0].id;
}

async function handleToolCall(name, args) {
  switch (name) {
    case 'list-peers': {
      let path = '/api/peers';
      const params = [];
      if (args.name) params.push(`name=${encodeURIComponent(args.name)}`);
      if (args.ip) params.push(`ip=${encodeURIComponent(args.ip)}`);
      if (params.length) path += '?' + params.join('&');
      const peers = await api(path);
      return peers.map(p => ({
        id: p.id, name: p.name, ip: p.ip, dns_label: p.dns_label,
        connected: p.connected, os: p.os, last_seen: p.last_seen,
        hostname: p.hostname, version: p.version,
      }));
    }
    case 'rename-peer': {
      let id = args.peerId;
      if (!id) {
        if (!args.currentName) throw new Error('Provide either peerId or currentName');
        id = await findPeerId(args.currentName);
      }
      await api(`/api/peers/${id}`, {
        method: 'PUT',
        body: JSON.stringify({
          name: args.newName,
          ssh_enabled: true,
          login_expiration_enabled: false,
          inactivity_expiration_enabled: false,
        }),
      });
      return { success: true, peerId: id, newName: args.newName };
    }
    case 'get-peer': {
      let id = args.peerId;
      if (!id) {
        if (!args.name) throw new Error('Provide either peerId or name');
        id = await findPeerId(args.name);
      }
      return api(`/api/peers/${id}`);
    }
    case 'get-peer-by-ip': {
      const peers = await api(`/api/peers?ip=${encodeURIComponent(args.ip)}`);
      if (peers.length === 0) throw new Error(`No peer found with IP "${args.ip}"`);
      return peers[0];
    }
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

// MCP stdio transport
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
      const req = JSON.parse(trimmed);
      handleRequest(req);
    } catch (e) {
      // ignore parse errors
    }
  }
});

async function handleRequest(req) {
  const send = (result) => {
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
          serverInfo: { name: 'netbird-mcp', version: '1.0.0' },
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
