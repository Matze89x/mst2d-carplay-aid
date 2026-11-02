'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { stageConf, patchHmi } = require('../tools/build-stage.cjs');
const eu = require('../targets/MST2_EU_VW_P0879D.json');

const BASE = 'BOOTCLASSPATH="/ifs1/delphi.jxe:/ifs1/MIBHMI.jxe:/x/GEM.jar"';
const JAR = '/extbin/apps/mst2-eu-carplay-maps/mst2-eu-rgi-hmi.jar';

test('patchHmi keeps community patches that only extend the variable (NavIgnore style)', () => {
  const text = `a\n${BASE}\nBOOTCLASSPATH="$BOOTCLASSPATH -Xbootclasspath/p:$MIBJAR/NavActiveIgnore.jar"\nPARAMETERS="$PARAMETERS -Xbootclasspath:$BOOTCLASSPATH"\n`;
  const result = patchHmi(text);
  assert.match(result, new RegExp(`BOOTCLASSPATH="/ifs1/delphi\\.jxe:/ifs1/MIBHMI\\.jxe:/x/GEM\\.jar:${JAR.replace(/[.\/]/g, '\\$&')}"`));
  assert.match(result, /NavActiveIgnore\.jar"/);
  assert.equal(result.split('\n').length, text.split('\n').length);
  assert.throws(() => patchHmi(result), /already patched/);
});

test('patchHmi rejects unrelated BOOTCLASSPATH assignments', () => {
  assert.throws(() => patchHmi(`${BASE}\nBOOTCLASSPATH="other"\n`), /unrecognized/);
  assert.throws(() => patchHmi('nothing here\n'), /unrecognized/);
});

test('stageConf lists the expectations of the target and only safe characters', () => {
  const euConf = stageConf(eu);
  assert.match(euConf, /^TARGET_TRAIN='MST2_EU_VW_P0879D'$/m);
  assert.match(euConf, /^EXPECT_HMI_NAVIGNORE='12222 [0-9a-f]{64}'$/m);
  assert.match(euConf, /^HMI_VARIANTS='STOCK NAVIGNORE'$/m);
  assert.doesNotMatch(euConf, /[$`"\\;&|<>]/);
});

test('EU target is a complete description of MST2_EU_VW_P0879D', () => {
  assert.equal(eu.platform, 'MST2');
  assert.equal(eu.vendor, 'DELPHI');
  assert.equal(eu.region, 'EU');
  assert.equal(eu.release, 'MST2_EU_VW_P0879D');
  assert.equal(eu.requiredEntries.length, 14);
  for (const entry of eu.requiredEntries) assert.match(entry.sha256, /^[0-9a-f]{64}$/);
  assert.match(eu.extbinAppsSHA256, /^[0-9a-f]{64}$/);
  assert.match(eu.staticBindings.navigationServer.transportStreamPackagesReadyVirtualAddress, /^0x[0-9a-f]+$/);
});

test('installer checks the SD card first and backs up twice; uninstaller removes everything from the unit', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const install = fs.readFileSync(path.join(__dirname, '..', 'installer', 'install.sh'), 'utf8');
  const uninstall = fs.readFileSync(path.join(__dirname, '..', 'installer', 'uninstall.sh'), 'utf8');
  assert.match(install, /sd_writable "\$SD_BACKUP_DIR" \|\| fail/);
  assert.ok(install.indexOf('sd_writable "$SD_BACKUP_DIR" || fail') < install.indexOf('expect_pair "$APP_ROOT/cfg/iap2.cfg"'), 'SD check comes before any inspection');
  assert.match(install, /sd_copy "\$ETC_DIR\/procman_core\.cfg" procman_core\.cfg/);
  assert.match(uninstall, /rmdir "\$MMI_BACKUP_DIR"/);
  assert.match(uninstall, /nichts von diesem Projekt zurueckgeblieben/);
  assert.doesNotMatch(install, /rm\s+-rf/);
  assert.doesNotMatch(uninstall, /rm\s+-rf/);
});
