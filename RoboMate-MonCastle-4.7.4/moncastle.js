'use strict';
// RoboMate MonCastle (user package). The console is in app.mcpak, compressed, encrypted (AES-256-GCM) and
// integrity-checked; this loader decrypts it in memory and starts it. Nothing from it is written to disk.
//   node moncastle.js [--demo]                     start the console
//   node moncastle.js --tool set-override-password  run a packaged tool
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');
const Module = require('module');
const { Readable } = require('stream');

const ROOT = __dirname;
const raw = fs.readFileSync(path.join(ROOT, 'app.mcpak'));
if (raw.subarray(0, 5).toString() !== 'MCPK1' || crypto.createHash('sha256').update(raw).digest('hex') !== '89b66f4f5def5861cce7b7ae8491490f4d6e0e0daacc8584f2cc99abef2ae45f') {
  console.error('app.mcpak is damaged or was changed. Reinstall this MonCastle version.'); process.exit(3);
}
const a = Buffer.from('jTA25mM5u63fQXw4lrH0A6X2OJP0CAEMBD9ERqQK/uw=', 'base64'), b = Buffer.from('4768/LfgqpPSOf7zXWcfT8lnZ1SSM4uaJ2MEHUR4GQ8=', 'base64');
const d = crypto.createDecipheriv('aes-256-gcm', Buffer.from(a.map((x, i) => x ^ b[i])), raw.subarray(5, 17));
d.setAuthTag(raw.subarray(17, 33));
const pack = JSON.parse(zlib.gunzipSync(Buffer.concat([d.update(raw.subarray(33)), d.final()])).toString('utf8'));
a.fill(0); b.fill(0);

const V = new Map(), DIRS = new Set();
for (const [rel, data] of Object.entries(pack.files)) {
  const p = path.join(ROOT, ...rel.split('/'));
  V.set(p, Buffer.from(data, 'base64'));
  for (let x = path.dirname(p); x.length > ROOT.length; x = path.dirname(x)) DIRS.add(x);
}
pack.files = null;
const BUILT = new Date(pack.built);

// read-only overlay: paths inside the package come from memory, everything else from the disk
const real = { existsSync: fs.existsSync, readFileSync: fs.readFileSync, statSync: fs.statSync, stat: fs.stat, createReadStream: fs.createReadStream };
const key = (p) => { try { return path.resolve(p instanceof URL ? require('url').fileURLToPath(p) : String(p)); } catch (e) { return null; } };
const statOf = (k) => {
  const file = V.has(k);
  return { isFile: () => file, isDirectory: () => !file, isSymbolicLink: () => false, size: file ? V.get(k).length : 0, mtime: BUILT, mtimeMs: +BUILT, ctime: BUILT, birthtime: BUILT, mode: file ? 0o100444 : 0o40555 };
};
fs.existsSync = function (p) { const k = key(p); return (k && (V.has(k) || DIRS.has(k))) || real.existsSync.apply(fs, arguments); };
fs.readFileSync = function (p, o) {
  const k = typeof p === 'number' ? null : key(p);
  if (k && V.has(k)) { const buf = V.get(k), enc = typeof o === 'string' ? o : o && o.encoding; return enc ? buf.toString(enc) : Buffer.from(buf); }
  return real.readFileSync.apply(fs, arguments);
};
fs.statSync = function (p) { const k = key(p); if (k && (V.has(k) || DIRS.has(k))) return statOf(k); return real.statSync.apply(fs, arguments); };
fs.stat = function (p, o, cb) { const k = key(p); if (k && (V.has(k) || DIRS.has(k))) { const done = typeof o === 'function' ? o : cb; return process.nextTick(done, null, statOf(k)); } return real.stat.apply(fs, arguments); };
fs.createReadStream = function (p) { const k = key(p); if (k && V.has(k)) return Readable.from([V.get(k)]); return real.createReadStream.apply(fs, arguments); };

// require() for modules inside the package
const resolve = Module._resolveFilename;
Module._resolveFilename = function (request, parent) {
  if (typeof request === 'string' && (request.startsWith('.') || path.isAbsolute(request))) {
    const base = parent && parent.filename ? path.dirname(parent.filename) : ROOT;
    const p = path.resolve(base, request);
    for (const c of [p, p + '.js', p + '.json', path.join(p, 'index.js')]) if (V.has(c)) return c;
  }
  return resolve.apply(this, arguments);
};
const js = Module._extensions['.js'], json = Module._extensions['.json'];
Module._extensions['.js'] = function (m, f) { if (V.has(f)) return m._compile(V.get(f).toString('utf8'), f); return js.apply(this, arguments); };
Module._extensions['.json'] = function (m, f) { if (V.has(f)) { m.exports = JSON.parse(V.get(f).toString('utf8')); return; } return json.apply(this, arguments); };

process.env.MC_PACKAGED = '1';
const t = process.argv.indexOf('--tool');
if (t > 0) require(path.join(ROOT, 'tools', String(process.argv[t + 1] || '').replace(/[^\w-]/g, '') + '.js'));
else require(path.join(ROOT, 'server', 'index.js'));
