#!/usr/bin/env bash
# dist-bauen.sh — Trockenlauf: baut das Release-Zip lokal genau so, wie der
# Packager es in der GitHub Action tun wuerde, und prueft es. Laedt nichts hoch.
#
#   tools/dist-bauen.sh
#
# Warum es dieses Skript gibt und nicht nur "release.sh -d":
# Auf dem Entwicklungsrechner sind **zip und unzip nicht installiert**. release.sh baut das Archiv
# mit "zip -X -r" (Zeile 2776) und scheitert deshalb im letzten Schritt. Also:
#   1. release.sh -d -z   -> Staging-Baum .release/ bauen, kein Zip, kein Upload.
#      Das ist der Teil, der .pkgmeta, move-folders, ignore und die TOCs prueft.
#   2. Zip aus .release/ mit python3 -m zipfile-Logik nachbauen (Deflate, relative
#      Pfade, vier Ordner auf oberster Ebene) -> dist/.
#   3. Pruefen: vier Ordner, keine Doku-Flut, kein luac.out, jede TOC da,
#      alle Lua-Dateien syntaktisch in Ordner 5.1.
#
# In der Action laeuft stattdessen der echte "zip". Der Inhalt ist derselbe;
# Unterschied sind nur Zeitstempel und Dateiattribute.
#
# Ergebnis: dist/Lyra_Gestalt-<version>.zip  (nicht committen, steht in .gitignore)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

ZIPNAME="${1:-}"

# --- 1. Packager holen und Staging bauen ------------------------------------
if [ ! -x ./release.sh ]; then
  echo "== release.sh holen =="
  curl -sfL https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh -o release.sh
  chmod +x release.sh
fi

echo "== Staging bauen (release.sh -d -z: kein Upload, kein Zip) =="
rm -rf .release
./release.sh -d -z

STAGE="$REPO/.release"
[ -d "$STAGE" ] || { echo "FEHLER: .release fehlt"; exit 1; }

# --- 2. Zip bauen -----------------------------------------------------------
VERSION="$(git describe --tags --always --dirty 2>/dev/null || echo unversioniert)"
[ -n "$ZIPNAME" ] || ZIPNAME="Lyra_Gestalt-${VERSION}-classic.zip"
mkdir -p dist
ZIP="$REPO/dist/$ZIPNAME"
rm -f "$ZIP"

echo "== Zip bauen: dist/$ZIPNAME =="
python3 - "$STAGE" "$ZIP" <<'PY'
import os, sys, zipfile
stage, ziel = sys.argv[1], sys.argv[2]
pfade = []
for wurzel, dirs, dateien in os.walk(stage):
    dirs.sort(); dateien.sort()
    for d in dateien:
        p = os.path.join(wurzel, d)
        pfade.append((os.path.relpath(p, stage), p))
pfade.sort()
with zipfile.ZipFile(ziel, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for rel, absp in pfade:
        z.write(absp, rel)
print(f"  {len(pfade)} Dateien")
PY

# --- 3. Pruefen -------------------------------------------------------------
echo "== Zip pruefen =="
python3 - "$ZIP" <<'PY'
import sys, zipfile, collections, os, subprocess, tempfile
zp = sys.argv[1]
fehler = []
z = zipfile.ZipFile(zp)
namen = z.namelist()

ordner = sorted({n.split("/")[0] for n in namen})
erwartet = ["Lyra_Gestalt", "Lyra_Gestalt_Daten",
            "Lyra_Gestalt_Stimme_de", "Lyra_Gestalt_Stimme_en"]
print("Ordner auf oberster Ebene:", ordner)
if ordner != erwartet:
    fehler.append(f"Ordner falsch: {ordner} != {erwartet}")

tocs = ["Lyra_Gestalt/Lyra_Gestalt.toc",
        "Lyra_Gestalt/Lyra_Gestalt_Vanilla.toc",
        "Lyra_Gestalt_Stimme_de/Lyra_Gestalt_Stimme_de.toc",
        "Lyra_Gestalt_Stimme_en/Lyra_Gestalt_Stimme_en.toc",
        "Lyra_Gestalt_Daten/Lyra_Gestalt_Daten.toc"]
for t in tocs:
    if t not in namen:
        fehler.append(f"TOC fehlt: {t}")
print(f"TOC-Dateien: {len([t for t in tocs if t in namen])}/{len(tocs)} vorhanden")

lizenzen = ["Lyra_Gestalt/LICENSE", "Lyra_Gestalt/LICENSE-ASSETS.md",
            "Lyra_Gestalt_Daten/LICENSE"]
for l in lizenzen:
    if l not in namen:
        fehler.append(f"Lizenz fehlt: {l}")
print("Lizenzdateien:", [l for l in lizenzen if l in namen])

mds = [n for n in namen if n.lower().endswith(".md")]
print("Markdown im Zip:", mds)
if len(mds) > 1:
    fehler.append(f"Doku-Flut: {len(mds)} .md-Dateien, erwartet nur LICENSE-ASSETS.md")

verboten = [n for n in namen if
            os.path.basename(n) == "luac.out"
            or n.lower().endswith((".wav", ".xcf", ".psd", ".pyc"))
            or "Persoenlich/" in n
            or os.path.basename(n) in ("README.md", "CHANGELOG.md", "CONTRIBUTING.md",
                                       "AUDIT.md", "DESIGN.md", "INTERAKTION.md")
            or os.path.basename(n) == "Gefahren_Beispiel.lua"
            or n.startswith(("tools/", "docs/", ".github/"))]
if verboten:
    fehler.append(f"Verbotener Inhalt: {verboten}")
else:
    print("Verbotener Inhalt: keiner")

# Platzhalter duerfen nicht ausgeliefert werden. Lokal nur eine Warnung -
# das Zip soll fuer den Einbau-Test im Spiel trotzdem entstehen. Hart blockt
# der gate-Job in .github/workflows/release.yml, bevor etwas hochgeht.
warnungen = []
for l in lizenzen:
    if l in namen and b"[[" in z.read(l):
        warnungen.append(f"Offener [[Platzhalter]] in {l} - vor dem Upload ersetzen")

typen = collections.Counter(os.path.splitext(n)[1].lower() for n in namen)
print("Dateitypen:", dict(typen.most_common()))
roh = sum(i.file_size for i in z.infolist())
print(f"Dateien: {len(namen)} | Zip: {os.path.getsize(zp)/2**20:.1f} MiB "
      f"| entpackt: {roh/2**20:.1f} MiB")

# Lua-Syntax in 5.1-Semantik (luajit), sonst luac.
pruefer = None
for kandidat in (["luajit", "-bl"], ["luac", "-p", "-o", os.devnull]):
    if subprocess.run(["which", kandidat[0]], capture_output=True).returncode == 0:
        pruefer = kandidat
        break
luas = [n for n in namen if n.endswith(".lua")]
if pruefer is None:
    print(f"Lua-Pruefung uebersprungen (kein luajit/luac): {len(luas)} Dateien")
else:
    kaputt = []
    with tempfile.TemporaryDirectory() as td:
        for n in luas:
            f = os.path.join(td, "x.lua")
            with open(f, "wb") as fh:
                fh.write(z.read(n))
            cmd = pruefer + [f] + ([os.devnull] if pruefer[0] == "luajit" else [])
            r = subprocess.run(cmd, capture_output=True)
            if r.returncode != 0:
                kaputt.append((n, r.stderr.decode()[:200]))
    print(f"Lua-Syntax ({pruefer[0]}): {len(luas) - len(kaputt)}/{len(luas)} in Ordnung")
    for n, e in kaputt:
        fehler.append(f"Lua-Syntaxfehler {n}: {e}")

print()
if fehler:
    print("FEHLER:")
    for f in fehler:
        print("  -", f)
    sys.exit(1)
print("Zip in Ordnung.")
if warnungen:
    print()
    print("NICHT VEROEFFENTLICHUNGSREIF:")
    for w in warnungen:
        print("  -", w)
    print("  Das Zip ist installierbar und fuer den Test im Spiel brauchbar,")
    print("  darf aber nicht hochgeladen werden. Gate: docs/release-ablauf.md §1.")
PY

echo
echo "Ergebnis: $ZIP"
