#!/usr/bin/env node
'use strict';
// Prueft die festen Adressen und Funktionsanfaenge der Zielbeschreibung (targets/*.json) gegen die ENTPACKTE Original-
// Firmware. Es wird nichts ausgefuehrt, nur gelesen. Dieselben Werte pruefen die Hooks zur Laufzeit auf dem Geraet.
// Verifies the fixed addresses and function prologues of the target description (targets/*.json) against the UNPACKED
// stock firmware. Nothing is executed, only read. The hooks check the same values at runtime on the unit.
//
// Aufruf / Usage:  node tools/verify-static-bindings.cjs <target.json> <apps.tmp>

const fs = require('node:fs');
const path = require('node:path');
const { elfSegments, vaddrToOffset, offsetToVaddr } = require('./make-target.cjs');

function sections(data) {
  const shoff = data.readUInt32LE(32), shentsize = data.readUInt16LE(46), shnum = data.readUInt16LE(48);
  const list = [];
  for (let i = 0; i < shnum; i += 1) {
    const b = shoff + i * shentsize;
    list.push({ type: data.readUInt32LE(b + 4), offset: data.readUInt32LE(b + 16), size: data.readUInt32LE(b + 20), link: data.readUInt32LE(b + 24), entsize: data.readUInt32LE(b + 36) });
  }
  return list;
}
function dynamicSymbols(data) {
  const all = sections(data);
  const dynsym = all.find((s) => s.type === 11);
  if (!dynsym) throw new Error('no .dynsym');
  const str = all[dynsym.link];
  const out = new Map();
  for (let o = dynsym.offset; o < dynsym.offset + dynsym.size; o += 16) {
    const nameOffset = data.readUInt32LE(o), value = data.readUInt32LE(o + 4), shndx = data.readUInt16LE(o + 14);
    if (!nameOffset || shndx === 0) continue;
    const start = str.offset + nameOffset;
    const name = data.subarray(start, data.indexOf(0, start)).toString('latin1');
    out.set(name, value);
  }
  return out;
}
const num = (text) => Number.parseInt(text, 16);
const hex = (n) => `0x${n.toString(16)}`;

function verify(target, apps) {
  const results = [];
  const check = (ok, text) => results.push({ ok: Boolean(ok), text });
  const read = (relative) => fs.readFileSync(path.join(apps, ...relative.split('/')));
  const sb = target.staticBindings;

  // 1. iAP2-Treiber: Symbole und beschreibbare Tabellen / iAP2 driver: symbols and writable tables
  const drv = read('lib/ipod-drvr-iap2.so');
  const segs = elfSegments(drv, 'ipod-drvr-iap2.so');
  const sym = dynamicSymbols(drv);
  const rt = sb.ipodDriverRuntime;
  const module = sym.get('ipod_module');
  check(module === num(rt.ipodModule), `ipod_module = ${hex(module || 0)} (Vorgabe ${rt.ipodModule})`);
  check(sym.get('packet_addparam_blob') === num(rt.packetAddParamBlob), `packet_addparam_blob = ${hex(sym.get('packet_addparam_blob') || 0)} (Vorgabe ${rt.packetAddParamBlob})`);
  check(sym.get('ident_info_funcs') === num(rt.identifyBuilderTable), `ident_info_funcs = ${hex(sym.get('ident_info_funcs') || 0)} (Vorgabe ${rt.identifyBuilderTable})`);
  check(sym.get('iap2_ctrl_msg_table') === num(rt.controlMessageTable), `iap2_ctrl_msg_table = ${hex(sym.get('iap2_ctrl_msg_table') || 0)} (Vorgabe ${rt.controlMessageTable})`);
  const slotAt = vaddrToOffset(segs, num(rt.gpsBuilderSlot));
  check(slotAt >= 0 && drv.readUInt32LE(slotAt) === 0x16 && drv.readUInt32LE(slotAt + 4) === num(rt.gpsBuilder),
    `GPS-Slot bei ${rt.gpsBuilderSlot}: Wort0=0x16 und Wort1=${rt.gpsBuilder} (Datei: ${slotAt >= 0 ? `${hex(drv.readUInt32LE(slotAt))}, ${hex(drv.readUInt32LE(slotAt + 4))}` : 'ausserhalb'})`);
  const groupAt = vaddrToOffset(segs, num(rt.controlMessageTable) + 0x52 * 12);
  check(groupAt >= 0 && drv.subarray(groupAt, groupAt + 12).toString('hex') === rt.controlGroup52InitialBytes, `Nachrichtengruppe 0x52 ist unbelegt (12 Nullbytes): ${groupAt >= 0 ? drv.subarray(groupAt, groupAt + 12).toString('hex') : 'ausserhalb'}`);

  // 2. libiap2client: rohe Sendefunktion / raw send function
  const cli = read('lib/libiap2client.so');
  const cliSym = dynamicSymbols(cli);
  const cliSegs = elfSegments(cli, 'libiap2client.so');
  const rawName = sb.libiap2client.rawSendExport;
  check(cliSym.has(rawName) && offsetToVaddr(cliSegs, num(sb.libiap2client.rawSendFileOffset)) === cliSym.get(rawName),
    `${rawName} liegt bei Dateioffset ${sb.libiap2client.rawSendFileOffset} (Symbol ${hex(cliSym.get(rawName) || 0)})`);

  // 3. libAirPlay: Symbole und Funktionsanfaenge / symbols and prologues
  const air = read('lib/libAirPlay.so');
  const airSegs = elfSegments(air, 'libAirPlay.so');
  const airSym = dynamicSymbols(air);
  for (const [name, b] of Object.entries(sb.libAirPlay)) {
    const want = num(b.virtualAddress);
    const symName = name === 'AirPlay_DeriveAESKeySHA512ForScreen' || airSym.has(name) ? name : null;
    const at = vaddrToOffset(airSegs, want);
    const prologueOk = b.prologue === undefined || (at >= 0 && air.subarray(at, at + b.prologue.length / 2).toString('hex') === b.prologue);
    check(symName && airSym.get(symName) === want && prologueOk, `${name} bei ${b.virtualAddress}${b.prologue ? `, Anfang ${b.prologue}` : ''}`);
  }

  // 4. NavigationServer: Hook-Funktion und Transportpfad / hook function and transport path
  const nav = read('bin/NavigationServer');
  const navSegs = elfSegments(nav, 'NavigationServer');
  const prologue = Buffer.from(sb.navigationServer.transportStreamPackagesReadyPrologue, 'hex');
  const hits = []; for (let at = nav.indexOf(prologue); at >= 0; at = nav.indexOf(prologue, at + 1)) hits.push(at);
  check(hits.length === 1 && offsetToVaddr(navSegs, hits[0]) === num(sb.navigationServer.transportStreamPackagesReadyVirtualAddress),
    `NavigationServer-Funktion genau einmal, bei ${sb.navigationServer.transportStreamPackagesReadyVirtualAddress} (gefunden: ${hits.length}x, ${hits.length ? hex(offsetToVaddr(navSegs, hits[0])) : '-'})`);
  check(nav.includes(Buffer.from(sb.navigationServer.isoTxPath)), `Transportpfad ${sb.navigationServer.isoTxPath} ist im NavigationServer vorhanden`);
  return results;
}

function main(argv) {
  if (argv.length !== 2) throw new Error('usage: node tools/verify-static-bindings.cjs <target.json> <apps.tmp>');
  const target = JSON.parse(fs.readFileSync(path.resolve(argv[0]), 'utf8'));
  const results = verify(target, path.resolve(argv[1]));
  for (const r of results) process.stdout.write(`${r.ok ? 'OK     ' : 'FEHLER '} ${r.text}\n`);
  const bad = results.filter((r) => !r.ok).length;
  process.stdout.write(`\n${results.length} Pruefungen, ${bad} Fehler / ${results.length} checks, ${bad} failures\n`);
  if (bad) process.exitCode = 1;
}
if (require.main === module) { try { main(process.argv.slice(2)); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 2; } }
module.exports = { verify, dynamicSymbols };
