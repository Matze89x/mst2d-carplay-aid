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
  assert.match(uninstall, /t_rmdir "\$MMI_BACKUP_DIR"/);
  assert.match(uninstall, /nichts von diesem Projekt zurueckgeblieben/);
  assert.doesNotMatch(install, /rm\s+-rf/);
  assert.doesNotMatch(uninstall, /rm\s+-rf/);
});

test('installer scripts call only the programs the radio is known to have; the rest goes through tools.sh', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  // Erster Test im Radio: dirname, cksum, id, tail, uptime, expr fehlen beim Start / first test in a radio: these are missing at boot
  const banned = /(^|[\s(|;`$])(dirname|basename|cksum|tail|head|cut|awk|expr|id|uptime|wc|tr|cmp|diff|touch|sed|sha256sum|rmdir)(\s|$)/;
  for (const name of ['install.sh', 'uninstall.sh']) {
    const lines = fs.readFileSync(path.join(__dirname, '..', 'installer', name), 'utf8').split('\n');
    lines.forEach((line, index) => {
      const code = line.trim();
      if (code.startsWith('#') || /^\s*(echo|fail)\b/.test(code) || /"[^"]*\b(cmp|diff|sha256sum|cksum)\b[^"]*"/.test(code)) return;
      assert.doesNotMatch(code, banned, `${name}:${index + 1} calls a program the radio may not have: ${code}`);
    });
    assert.match(lines.join('\n'), /\. "\$SELF_DIR\/tools\.sh"/);
  }
});

test('native hooks use the QNX 6.5 dlsym handles and never call an unresolved function', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const src = (name) => fs.readFileSync(path.join(__dirname, '..', 'native', 'delphi-qnx', name), 'utf8');
  // Das echte QNX-6.5-<dlfcn.h>: RTLD_DEFAULT -2, RTLD_NEXT -3. Die frueheren Werte 0/-1 liessen dlsym NULL liefern und
  // stuerzten den NavigationServer beim Start ab (signal 11, ip 0). / the real QNX 6.5 <dlfcn.h> values
  const header = src('include/dcc_qnx.h');
  assert.match(header, /#define RTLD_DEFAULT \(\(void \*\)-2\)/);
  assert.match(header, /#define RTLD_NEXT \(\(void \*\)-3\)/);
  const gate = src('src/video_gate.c');
  for (const call of ['open', 'close', 'write', 'writev']) {
    assert.match(gate, new RegExp(`if \\(!next\\) return -1;`), `${call} wrapper checks the real function`);
    assert.doesNotMatch(gate, new RegExp(`dlsym\\(RTLD_NEXT, "${call}"\\)`), `${call}: no unchecked dlsym`);
  }
  assert.equal((gate.match(/if \(!next\) return -1;/g) || []).length, 4);
  assert.match(src('src/launch_hook.c'), /if\(!next\)return -1;/);
  assert.match(src('src/airplay_hook.c'), /dcc_library_symbol\("libAirPlaySupport\.so"/);
});

test('the iPhone hook leaves its component out once the stock driver counted a rejection', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const hook = fs.readFileSync(path.join(__dirname, '..', 'native', 'delphi-qnx', 'src', 'ipod_hook.c'), 'utf8');
  // Treiber ipod-drvr-iap2.so (P0879D), link_handle_payload 0x169b0: dev[0xb0]++, ab dem 7. Ablehnung exit(-1).
  assert.match(hook, /#define REJECT_COUNT_OFFSET 0xb0u/);
  assert.match(hook, /rejected!=0u/);
  assert.match(hook, /rejections so far/);
  // Das Log wird fortgeschrieben, nicht bei jedem Eintrag ueberschrieben. / the log is appended to
  assert.match(hook, /lseek\(fd,0,SEEK_END\)/);
});
