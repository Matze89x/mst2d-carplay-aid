# Routenführungs-Kern / Route-guidance core

**Deutsch zuerst – English version below: [English](#english).**

Portable C99-Auswertung und Sitzungslogik für CarPlay Route Guidance Information (RGI). Prüft Rahmen und TLVs, führt einen
atomaren Routenzustand, behandelt Zeitüberschreitung und Zurücksetzen und bereitet die iAP2-Identify-Angaben für den
Delphi-Hook vor.

```sh
cmake -S native/rgi -B build/rgi
cmake --build build/rgi
ctest --test-dir build/rgi --output-on-failure
```

---

<a id="english"></a>

Portable C99 parsing and session logic for CarPlay Route Guidance Information (RGI). It validates frames and TLVs,
maintains atomic route state, handles timeout and reset, and prepares the iAP2 Identify declarations used by the Delphi
hook.

```sh
cmake -S native/rgi -B build/rgi
cmake --build build/rgi
ctest --test-dir build/rgi --output-on-failure
```
