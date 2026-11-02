#!/usr/bin/env node
'use strict';
// Erzeugt eine Ziel-Beschreibung (targets/*.json) fuer eine weitere Delphi-MST2-Firmware aus einer
// bestehenden Vorlage. Es werden nur Pruefsummen und Adressen berechnet bzw. geprueft; es wird nichts
// ausgefuehrt und keine Firmware weitergegeben.
//
// Generates a target description (targets/*.json) for another Delphi MST2 firmware from an existing
// template. It only computes/validates hashes and addresses; nothing is executed and no firmware
// is redistributed.
//
// Aufruf / Usage:
//   node tools/make-target.cjs --template targets/MST2_EU_VW_P0879D.json \
//     --apps <apps.tmp> --stdf <STDF.bin> --extbin <EXTBIN_APPS.bin> \
//     --id MST2_EU_VW_P0879D_STD2Nav_EU_VW --region EU --release MST2_EU_VW_P0879D \
//     --variant STD2Nav_EU_VW --mu 0879 --out targets/MST2_EU_VW_P0879D.json

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

function sha256(data) { return crypto.createHash('sha256').update(data).digest('hex'); }

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 2) {
    if (!argv[i].startsWith('--') || argv[i + 1] === undefined) throw new Error(`bad argument: ${argv[i]}`);
    out[argv[i].slice(2)] = argv[i + 1];
  }
  return out;
}

// ELF32 little endian: Dateioffset <-> virtuelle Adresse ueber die PT_LOAD-Segmente / file offset <-> virtual address via PT_LOAD
function elfSegments(data, name) {
  if (data.length < 52 || data.readUInt32BE(0) !== 0x7f454c46 || data[4] !== 1 || data[5] !== 1) {
    throw new Error(`${name}: not an ELF32 little-endian file`);
  }
  const phoff = data.readUInt32LE(28), phentsize = data.readUInt16LE(42), phnum = data.readUInt16LE(44);
  const segments = [];
  for (let i = 0; i < phnum; i += 1) {
    const base = phoff + i * phentsize;
    if (data.readUInt32LE(base) !== 1) continue;
    segments.push({ offset: data.readUInt32LE(base + 4), vaddr: data.readUInt32LE(base + 8), filesz: data.readUInt32LE(base + 16) });
  }
  if (!segments.length) throw new Error(`${name}: no PT_LOAD segment`);
  return segments;
}
function vaddrToOffset(segments, vaddr) {
  const s = segments.find((x) => vaddr >= x.vaddr && vaddr < x.vaddr + x.filesz);
  return s ? vaddr - s.vaddr + s.offset : -1;
}
function offsetToVaddr(segments, offset) {
  const s = segments.find((x) => offset >= x.offset && offset < x.offset + x.filesz);
  return s ? offset - s.offset + s.vaddr : -1;
}
function findAll(data, pattern) {
  const hits = [];
  for (let at = data.indexOf(pattern); at >= 0; at = data.indexOf(pattern, at + 1)) hits.push(at);
  return hits;
}
const hex = (n) => `0x${n.toString(16)}`;

function procmanCore(stdf, templateFile) {
  const marker = Buffer.from('##  core managers\n');
  const found = [];
  for (let start = stdf.indexOf(marker); start >= 0; start = stdf.indexOf(marker, start + 1)) {
    const end = stdf.indexOf(0xff, start);
    if (end < 0) continue;
    const text = stdf.subarray(start, end);
    // procman_core.cfg startet das HMI ueber runHMI.sh; die Werkmodus-Datei procman_mfg.cfg nicht / the core file starts the HMI via runHMI.sh, the factory-mode file does not
    if (text.includes(Buffer.from('runHMI.sh')) && text.includes(Buffer.from('MediaHandler')) && text.includes(Buffer.from('NavigationServer')) && text.includes(Buffer.from('CarPlay'))) found.push(text);
  }
  if (found.length !== 1) throw new Error(`procman_core.cfg: expected exactly one match in STDF, found ${found.length}`);
  return { path: templateFile.path, bytes: found[0].length, sha256: sha256(found[0]) };
}

function make(options) {
  const template = JSON.parse(fs.readFileSync(options.template, 'utf8'));
  const apps = path.resolve(options.apps);
  const result = JSON.parse(JSON.stringify(template));
  result.id = options.id;
  result.region = options.region;
  result.release = options.release;
  result.variant = options.variant;
  result.muVersion = options.mu;
  result.extbinAppsSHA256 = sha256(fs.readFileSync(options.extbin));
  result.sourceArchiveSHA256 = null;

  const notes = [];
  result.requiredEntries = template.requiredEntries.map((entry) => {
    const relative = entry.path.replace(/^extbin\/apps\.tmp\//, '');
    const data = fs.readFileSync(path.join(apps, ...relative.split('/')));
    const same = sha256(data) === entry.sha256;
    notes.push(`${same ? 'identisch/identical' : 'abweichend/different'}  ${relative}`);
    return { path: entry.path, bytes: data.length, sha256: sha256(data) };
  });

  const stdf = fs.readFileSync(options.stdf);
  result.systemImages = { stdf: { archivePath: options.stdfArchivePath || template.systemImages.stdf.archivePath, bytes: stdf.length, sha256: sha256(stdf), procmanCore: procmanCore(stdf, template.systemImages.stdf.procmanCore) } };

  // Statische Bindungen: Bibliotheken muessen bytegleich sein oder die Pruefung der Funktionsanfaenge muss bestehen
  const lib = (name) => fs.readFileSync(path.join(apps, 'lib', name));
  const entryHash = (rel) => result.requiredEntries.find((e) => e.path === `extbin/apps.tmp/${rel}`).sha256;
  const tmplHash = (rel) => template.requiredEntries.find((e) => e.path === `extbin/apps.tmp/${rel}`).sha256;
  for (const rel of ['lib/ipod-drvr-iap2.so', 'lib/libiap2client.so']) {
    if (entryHash(rel) !== tmplHash(rel)) throw new Error(`${rel} differs from the template; the static bindings must be re-derived by hand`);
  }
  const airplay = lib('libAirPlay.so');
  const segments = elfSegments(airplay, 'libAirPlay.so');
  for (const [name, binding] of Object.entries(template.staticBindings.libAirPlay)) {
    if (binding.prologue === undefined) continue;
    const at = vaddrToOffset(segments, Number.parseInt(binding.virtualAddress, 16));
    const have = at < 0 ? '' : airplay.subarray(at, at + binding.prologue.length / 2).toString('hex');
    if (have !== binding.prologue) throw new Error(`libAirPlay ${name}: prologue mismatch at ${binding.virtualAddress}`);
  }
  notes.push('libAirPlay: alle Funktionsanfaenge stimmen / all prologues match');

  const nav = fs.readFileSync(path.join(apps, 'bin', 'NavigationServer'));
  const navSegments = elfSegments(nav, 'NavigationServer');
  const prologue = Buffer.from(template.staticBindings.navigationServer.transportStreamPackagesReadyPrologue, 'hex');
  const hits = findAll(nav, prologue);
  if (hits.length !== 1) throw new Error(`NavigationServer: expected exactly one prologue match, found ${hits.length}`);
  const vaddr = offsetToVaddr(navSegments, hits[0]);
  if (vaddr < 0) throw new Error('NavigationServer: prologue is not inside a loadable segment');
  result.staticBindings.navigationServer.transportStreamPackagesReadyVirtualAddress = hex(vaddr);
  notes.push(`NavigationServer: Hook-Funktion bei Dateioffset ${hex(hits[0])} = virtuelle Adresse ${hex(vaddr)}`);
  return { result, notes };
}

function main(argv) {
  const o = parseArgs(argv);
  for (const key of ['template', 'apps', 'stdf', 'extbin', 'id', 'region', 'release', 'variant', 'mu', 'out']) {
    if (!o[key]) throw new Error(`missing --${key}`);
  }
  if (fs.existsSync(o.out)) throw new Error(`refusing to overwrite ${o.out}`);
  const { result, notes } = make(o);
  fs.writeFileSync(o.out, `${JSON.stringify(result, null, 2)}\n`, { flag: 'wx' });
  process.stdout.write(`${notes.join('\n')}\nGeschrieben / written: ${o.out}\n`);
}

if (require.main === module) {
  try { main(process.argv.slice(2)); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }
}
module.exports = { make, elfSegments, vaddrToOffset, offsetToVaddr };
