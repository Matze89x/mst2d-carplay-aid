# Native QNX-Nutzlast (EU) / Native QNX payloads (EU)

**Deutsch zuerst – English version below: [English](#english).**

Freistehende ARMv7-Vorladebibliotheken für die exakten Prozesse CarPlay, MediaHandler, mm-ipod und NavigationServer des
Zielgeräts (`MST2_EU_VW_P0879D`). Alle Laufzeit-Hooks prüfen das Ziel vor der Aktivierung und tun bei einer Abweichung
nichts („fail closed").

Bauen und prüfen unter Linux mit Clang und LLD (am einfachsten in dem Container aus `tools/docker`):

```sh
sh native/delphi-qnx/build.sh
sh native/delphi-qnx/verify.sh
```

Die kleine `libc.so.3` unter `stubs/` ist nur eine Importfläche zum Linken. Sie wird nicht ausgeliefert und nicht auf dem
Gerät geladen.

---

<a id="english"></a>

Freestanding ARMv7 preload libraries for the exact CarPlay, MediaHandler, mm-ipod and NavigationServer processes of the
target unit (`MST2_EU_VW_P0879D`). All runtime hooks validate the target before activation and fail closed on a mismatch.

Build and verify on Linux with Clang and LLD (easiest inside the container from `tools/docker`):

```sh
sh native/delphi-qnx/build.sh
sh native/delphi-qnx/verify.sh
```

The minimal `libc.so.3` in `stubs/` is a link-only import surface. It is not shipped or loaded on the unit.
