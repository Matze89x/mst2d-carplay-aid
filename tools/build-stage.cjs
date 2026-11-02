#!/usr/bin/env node
'use strict';
// Baut das installierbare Stage-Verzeichnis fuer EIN Ziel (targets/*.json). Alle Eingaben werden gegen die
// Pruefsummen des Ziels geprueft; bei der kleinsten Abweichung wird nichts gebaut.
// Builds the installable stage directory for ONE target (targets/*.json). Every input is checked against
// the target's fingerprints; on the slightest mismatch nothing is built.
//
// Aufruf / Usage:
//   node tools/build-stage.cjs <target.json> <apps.tmp> <STDF.bin> <native-build-dir> <HMI-jar> <empty-output-dir>

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { rewriteIap2Config } = require('./build-iap2-config.cjs');

const INSTALL = '/extbin/apps/mst2-eu-carplay-maps';
const INPUTS = {
  iap2: 'cfg/iap2.cfg',
  hmi: 'hmi/HMI/runHMI.sh',
  bundles: 'hmi/HMI/config/bundles.properties',
  mediaHandler: 'bin/MediaHandler',
  ipod: 'usr/bin/mm-ipod',
  navigationServer: 'bin/NavigationServer',
};
const JAR = `${INSTALL}/mst2-eu-rgi-hmi.jar`;

function sha256(data) { return crypto.createHash('sha256').update(data).digest('hex'); }
function validateArmElf(data, name) {
  if (data.length < 52 || data[0] !== 0x7f || data.subarray(1, 4).toString('ascii') !== 'ELF' ||
      data[4] !== 1 || data[5] !== 1 || data.readUInt16LE(16) !== 3 || data.readUInt16LE(18) !== 40) {
    throw new Error(`${name} is not an ELF32 little-endian ARM shared object`);
  }
}
function validateJar(data) {
  if (data.length < 22 || data.readUInt32LE(0) !== 0x04034b50 || !data.includes(Buffer.from('mst2/eu/cluster/Activator.class'))) {
    throw new Error('HMI jar does not contain the route-guidance bundle activator');
  }
}
function expected(target, relative) {
  const suffix = `extbin/apps.tmp/${relative}`;
  return target.requiredEntries.find((entry) => entry.path === suffix);
}
function checkedRead(target, root, relative) {
  const data = fs.readFileSync(path.join(root, ...relative.split('/')));
  const want = expected(target, relative);
  if (!want || data.length !== want.bytes || sha256(data) !== want.sha256) {
    throw new Error(`${relative} is not the exact stock input of ${target.release}`);
  }
  return data;
}
function checkedProcman(target, stdfPath) {
  const stdf = fs.readFileSync(stdfPath), want = target.systemImages.stdf;
  if (stdf.length !== want.bytes || sha256(stdf) !== want.sha256) throw new Error(`STDF.bin is not the exact stock system image of ${target.release}`);
  const marker = Buffer.from('##  core managers\n'), file = want.procmanCore, matches = [];
  let start = 0;
  while ((start = stdf.indexOf(marker, start)) >= 0) {
    const end = stdf.indexOf(0xff, start); if (end < 0) break;
    const candidate = stdf.subarray(start, end);
    if (candidate.length === file.bytes && sha256(candidate) === file.sha256) matches.push(candidate);
    start += marker.length;
  }
  if (matches.length !== 1) throw new Error('exact procman_core.cfg is missing or ambiguous');
  return matches[0];
}

// Haengt das HMI-Jar an die Basis-Zuweisung des Boot-Klassenpfads an. Weitere Zuweisungen, die die Variable
// nur erweitern (z. B. Community-Patches wie "BOOTCLASSPATH=\"$BOOTCLASSPATH -Xbootclasspath/p:...\""), bleiben erhalten.
// Appends the HMI jar to the base boot class path assignment. Further assignments that only extend the
// variable (community patches) are preserved.
function patchHmi(text) {
  const base = text.match(/^BOOTCLASSPATH="(\/[^"]+)"$/gm);
  if (!base || base.length !== 1) throw new Error('unrecognized runHMI.sh boot class path');
  for (const line of text.split('\n')) {
    if (/^BOOTCLASSPATH=/.test(line) && !line.startsWith('BOOTCLASSPATH="/') && !line.startsWith('BOOTCLASSPATH="$BOOTCLASSPATH ')) {
      throw new Error('unrecognized runHMI.sh boot class path');
    }
  }
  const match = base[0].match(/^BOOTCLASSPATH="([^"]+)"$/);
  if (match[1].split(':').includes(JAR)) throw new Error('runHMI.sh is already patched');
  return text.replace(base[0], `BOOTCLASSPATH="${match[1]}:${JAR}"`);
}
function patchBundles(text) {
  const late = /^Bundle\.Startup\.Lateload = ([0-9,]+)$/m;
  const match = text.match(late);
  if (!match || /^Bundle\.Name\.98/m.test(text)) throw new Error('unrecognized or already patched bundles.properties');
  const output = text.replace(late, `${match[0]},98`);
  return `${output.replace(/\s*$/, '')}\n\n# MST2 EU route-guidance bridge\nBundle.Name.98 = MST2EURGI\nBundle.Activator.98 = mst2.eu.cluster.Activator\n`;
}
function patchProcman(text) {
  const media = ' -f  MediaHandler           -n"mediahandler"             -l20 -x10 -p12 -c0         -a"-c../cfg/MHConfig.cfg"';
  const nav = ' -f  NavigationServer       -n"navigationserver"         -l99  -x5   -r               -c6 -a"-fcfg" -a"../cfg/NAV/v0/NC/Delphi/NavServer.cfg"';
  const carplay15 = ' -f  CarPlay                -n"carplay"                  -l20 -x10 -r   -c15';
  if (text.split(media).length !== 2 || text.split(nav).length !== 2 || text.split(carplay15).length !== 2) {
    throw new Error('unrecognized or already patched procman_core.cfg');
  }
  const mediaReplacement = ` -f  env                    -n"mediahandler"             -l20 -x10 -p12 -c0         -a"LD_PRELOAD=${INSTALL}/libmst2_eu_launch.so" -a"MediaHandler" -a"-c../cfg/MHConfig.cfg"`;
  const navReplacement = ` -f  env                    -n"navigationserver"         -l99  -x5   -r               -c6 -a"LD_PRELOAD=${INSTALL}/libmst2_eu_video_gate.so" -a"NavigationServer" -a"-fcfg" -a"../cfg/NAV/v0/NC/Delphi/NavServer.cfg"`;
  const carplay15Replacement = ` -f  env                    -n"carplay"                  -l20 -x10 -r   -c15 -a"LD_PRELOAD=${INSTALL}/libmst2_eu_airplay.so" -a"CarPlay"`;
  return text.replace(media, mediaReplacement).replace(nav, navReplacement).replace(carplay15, carplay15Replacement);
}

// Erwartungswerte fuer den Installer als Shell-Datei. Nur Ziffern, Hexzeichen und Bezeichner, daher sicher.
// Expected values for the installer as a shell file. Digits, hex and identifiers only, hence safe.
function stageConf(target) {
  const line = (name, value) => {
    if (!/^[A-Za-z0-9_. -]+$/.test(String(value))) throw new Error(`unsafe value for ${name}`);
    return `${name}='${value}'`;
  };
  const pair = (e) => `${e.bytes} ${e.sha256}`;
  const rows = [
    '# erzeugt von tools/build-stage.cjs - nicht von Hand aendern / generated by tools/build-stage.cjs - do not edit',
    line('TARGET_ID', target.id),
    line('TARGET_TRAIN', target.release),
    line('TARGET_MU', target.muVersion),
    line('EXPECT_IAP2', pair(expected(target, INPUTS.iap2))),
    line('EXPECT_BUNDLES', pair(expected(target, INPUTS.bundles))),
    line('EXPECT_PROCMAN', pair(target.systemImages.stdf.procmanCore)),
    line('EXPECT_HMI_STOCK', pair(expected(target, INPUTS.hmi))),
  ];
  const variants = (target.knownVariants || {})[INPUTS.hmi] || [];
  for (const v of variants) rows.push(line(`EXPECT_HMI_${v.name.toUpperCase()}`, pair(v)));
  rows.push(line('HMI_VARIANTS', ['STOCK', ...variants.map((v) => v.name.toUpperCase())].join(' ')));
  return `${rows.join('\n')}\n`;
}

function mkdir(directory) { fs.mkdirSync(directory, { recursive: true }); }
function write(root, relative, data, mode = 0o644) {
  const output = path.join(root, ...relative.split('/'));
  mkdir(path.dirname(output)); fs.writeFileSync(output, data, { flag: 'wx', mode });
  return output;
}

function build({ target, firmwareRoot, stdf, nativeDir, hmiJar, output }) {
  if (fs.existsSync(output)) throw new Error(`refusing to overwrite ${output}`);
  for (const relative of Object.values(INPUTS)) checkedRead(target, firmwareRoot, relative);
  const binaries = ['libmst2_eu_ipod.so', 'libmst2_eu_launch.so', 'libmst2_eu_video_gate.so', 'libmst2_eu_airplay.so'];
  const native = {};
  for (const name of binaries) {
    const file = path.join(nativeDir, name);
    if (!fs.statSync(file).isFile()) throw new Error(`missing native artifact: ${name}`);
    native[name] = fs.readFileSync(file); validateArmElf(native[name], name);
  }
  if (!native['libmst2_eu_launch.so'].includes(Buffer.from(`${INSTALL}/libmst2_eu_ipod.so`))) throw new Error('launcher artifact has the wrong child preload path');
  if (!native['libmst2_eu_ipod.so'].includes(Buffer.from('/extbin/apps/lib/ipod-drvr-iap2.so'))) throw new Error('iAP2 artifact is not the Delphi hook');
  if (!native['libmst2_eu_video_gate.so'].includes(Buffer.from('/dev/transport_server/spawn/isoTX'))) throw new Error('video gate artifact has the wrong Delphi transport path');
  if (!native['libmst2_eu_airplay.so'].includes(Buffer.from('/dev/shmem/mst2_eu_alt111'))) throw new Error('AirPlay artifact has the wrong shared video path');
  if (!fs.statSync(hmiJar).isFile()) throw new Error('missing HMI jar');
  const jar = fs.readFileSync(hmiJar); validateJar(jar);
  const procman = checkedProcman(target, stdf);
  const staging = `${output}.partial-${process.pid}`;
  if (fs.existsSync(staging)) throw new Error(`temporary stage already exists: ${staging}`);
  mkdir(staging);
  const files = [];
  function add(relative, data, mode) {
    const file = write(staging, relative, data, mode);
    files.push({ path: relative, bytes: fs.statSync(file).size, sha256: sha256(fs.readFileSync(file)) });
  }
  try {
    for (const name of binaries) add(`payload/${name}`, native[name], 0o755);
    add('payload/mst2-eu-rgi-hmi.jar', jar);
    add('patched/hmi/HMI/runHMI.sh', patchHmi(checkedRead(target, firmwareRoot, INPUTS.hmi).toString('utf8')), 0o755);
    add('patched/hmi/HMI/config/bundles.properties', patchBundles(checkedRead(target, firmwareRoot, INPUTS.bundles).toString('utf8')));
    add('patched/cfg/iap2.cfg', rewriteIap2Config(checkedRead(target, firmwareRoot, INPUTS.iap2).toString('utf8')));
    add('patched/etc/procman_core.cfg', patchProcman(procman.toString('utf8')));
    add('stage.conf', stageConf(target));
    add('install.sh', fs.readFileSync(path.join(__dirname, '..', 'installer', 'install.sh')), 0o755);
    add('uninstall.sh', fs.readFileSync(path.join(__dirname, '..', 'installer', 'uninstall.sh')), 0o755);
    const manifest = {
      schemaVersion: 1, target: target.id, installDirectory: INSTALL,
      stockInputs: [...Object.values(INPUTS).map((relative) => expected(target, relative)), target.systemImages.stdf, target.systemImages.stdf.procmanCore],
      files,
    };
    add('stage-manifest.json', `${JSON.stringify(manifest, null, 2)}\n`);
    fs.renameSync(staging, output);
    return manifest;
  } catch (error) { fs.rmSync(staging, { recursive: true, force: true }); throw error; }
}

function main(argv) {
  if (argv.length !== 6) throw new Error('usage: node tools/build-stage.cjs <target.json> <apps.tmp> <STDF.bin> <native-build-dir> <HMI-jar> <empty-output-dir>');
  const [targetPath, firmwareRoot, stdf, nativeDir, hmiJar, output] = argv.map((value) => path.resolve(value));
  const target = JSON.parse(fs.readFileSync(targetPath, 'utf8'));
  const result = build({ target, firmwareRoot, stdf, nativeDir, hmiJar, output });
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}
if (require.main === module) { try { main(process.argv.slice(2)); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; } }
module.exports = { build, stageConf, patchBundles, patchHmi, patchProcman, validateArmElf, validateJar, INSTALL, JAR };
