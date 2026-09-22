#!/usr/bin/env bash
# release-sync.sh — spiegelt das Entwicklungs-Monorepo in das Release-Layout.
#
# Quelle der Wahrheit ist und bleibt  <Projekt>/addon/ .
# Dieses Repo ist eine ABLEITUNG. Wer hier am Addon-Code editiert, verliert die
# Änderung beim nächsten Lauf.
#
#   Quelle                        ->  Ziel (dieses Repo)
#   addon/Lyra_Gestalt/*          ->  .                  (Wurzel, TOC oben — Packager-Pflicht)
#   addon/Lyra_Gestalt_Stimme_de  ->  Pakete/Stimme_de
#   addon/Lyra_Gestalt_Stimme_en  ->  Pakete/Stimme_en
#   addon/Lyra_Gestalt_Daten      ->  Pakete/Daten
#   addon/CHANGELOG.md            ->  CHANGELOG.md
#   (erzeugt)                     ->  Lyra_Gestalt_Vanilla.toc
#
# Aufruf:
#   tools/release-sync.sh            # synchronisieren (idempotent, zweiter Lauf ist still)
#   tools/release-sync.sh --check    # nur berichten, nichts schreiben; Exit 1 bei Abweichung
#   tools/release-sync.sh --src /pfad/zu/addon
#
# Zeichen in der Ausgabe:  + neu   M geändert   - verwaist (gelöscht)   * erzeugt
#
# Die synchronisierten Pfade stehen in tools/sync-manifest.txt. Was dort beim
# letzten Lauf stand und diesmal nicht mehr entsteht, wird gelöscht — so
# verschwinden umbenannte oder entfernte Dateien auch hier.
#
# NICHT angetastet werden die repo-eigenen Dateien: README.md, LICENSE,
# LICENSE-ASSETS.md, CONTRIBUTING.md, .pkgmeta, .github/, docs/, tools/.

set -euo pipefail

ZIEL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUELLE="${LYRA_ADDON_SRC:-$(cd "$ZIEL/.." && pwd)/addon}"
MANIFEST="$ZIEL/tools/sync-manifest.txt"
MODUS=sync

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODUS=check ;;
    --src)   QUELLE="${2:?--src braucht einen Pfad}"; shift ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unbekannte Option: $1" >&2; exit 2 ;;
  esac
  shift
done

[ -d "$QUELLE/Lyra_Gestalt" ] || { echo "Quelle nicht gefunden: $QUELLE" >&2; exit 2; }

# ---------------------------------------------------------------------------
# Was NICHT mitkommt.
#
#   *.md          Entwicklerdoku (AUDIT, DESIGN, INTERAKTION, Sinne/*.MD …).
#                 README, LICENSE* und CONTRIBUTING dieses Repos sind
#                 handgeschrieben und gehören nicht zur Spiegelung;
#                 CHANGELOG.md wird unten einzeln kopiert.
#   Gefahren_Beispiel.lua  Schema-Beispiel, steht nicht in der TOC.
#   *.wav *.xcf *.psd      Rohmaterial. Ausgeliefert wird nur das gerenderte OGG/PNG.
#   Harnesses, render/, scratch-render/, tools/, docs/, spike/
#                 liegen im Monorepo ohnehin außerhalb von addon/, sind hier
#                 aber als Netz mit aufgeführt.
# REVIEW8: 'bilder' stand hier als Netz fuer einen Monorepo-Ordner, den es nie
#                 gab. Seit der Umbenennung gestalt/ -> bilder/ (0.8.0, weil
#                 Windows und macOS beim Entpacken Gestalt/ und gestalt/
#                 verschmelzen) heisst der TEXTUR-Ordner des Addons so - der
#                 Ausschluss haette alle 68 PNG aus dem Release geworfen, und
#                 zwar lautlos: das Zip waere gebaut, Lyra darin unsichtbar.
#   Lyra_Gestalt_Persoenlich  nutzerspezifisch, entsteht auf dem eigenen Rechner
#                 und gehört nicht ins Release-Zip. Liegt hier nur als Doku und
#                 leeres Muster unter docs/persoenlich/ (per .pkgmeta ignoriert).
# ---------------------------------------------------------------------------
AUSSCHLUSS_NAMEN=(
  '*.md' '*.wav' '*.xcf' '*.psd' '*.bak' '*~' '*.orig' '*.rej'
  'luac.out' '*.pyc' '*.pyo' '.DS_Store' 'Thumbs.db'
  'Gefahren_Beispiel.lua'
  '*harness*' '*_test.lua' '*-test.lua'
)
AUSSCHLUSS_ORDNER=(
  'render' 'scratch-render' 'tools' 'docs' 'spike'
  '__pycache__' '.git' 'harness' 'tests'
)

# Paketabbildung: "<Quellordner unter addon/>|<Zielpfad relativ zur Repo-Wurzel>"
PAKETE=(
  "Lyra_Gestalt|."
  "Lyra_Gestalt_Stimme_de|Pakete/Stimme_de"
  "Lyra_Gestalt_Stimme_en|Pakete/Stimme_en"
  "Lyra_Gestalt_Daten|Pakete/Daten"
)

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ABWEICHUNG=0

# ---------------------------------------------------------------------------
# TOC-Metadaten fuer das Release.
#
# addon/ bleibt unangetastet — die reinen Release-Felder (Lizenzverweis,
# Website, Projekt-IDs) setzt deshalb dieses Skript beim Spiegeln.
#
# Die drei Projekt-IDs stehen ABSICHTLICH als "# ##"-Kommentar da: eine
# erfundene ID wuerde den Packager gegen ein fremdes Projekt hochladen lassen.
# Fehlt die ID, ueberspringt er das Ziel kommentarlos — genau richtig, solange
# CurseForge/Wago noch nicht angelegt sind. Nach der Freigabe das fuehrende
# "# " entfernen und die echte ID eintragen (schritte-upload.md §3.10, §4.3).
# ---------------------------------------------------------------------------
# PORT 0.9.0 (18.09.2026): zweite Stufe fuer die ERZEUGTE Flavor-TOC.
#
# Die Basis-TOC traegt seit 0.9.0 die Packager-Zeilen
#     ## Interface-TBC: 20506  /  ## Interface-Mists: 50504  /  ## Interface-Mainline: 120100
# In einer Datei MIT Suffix (Lyra_Gestalt_Vanilla.toc) haben die dort nichts zu suchen: der
# Client ignoriert sie, release.sh prueft bei einer suffixierten TOC ohnehin nur die
# "## Interface:"-Zeile, und ein Leser, der Lyra_Gestalt_Vanilla.toc aufmacht und dort
# "Interface-Mainline: 120100" findet, denkt zu Recht, hier stimmt etwas nicht.
# Also raus damit — samt dem erklaerenden Kommentarblock, der an ihnen haengt.
#
# Der Block wird an der ERSTEN "## Title"-Zeile beendet, nicht ueber eine Zeilenzahl: der
# Kommentar im Kern-TOC darf wachsen, ohne dass dieses Skript nachgezogen werden muss.
flavor_filter() {  # liest stdin, schreibt stdout
  awk '
    /^## Interface-/ { imBlock = 1; next }
    imBlock && /^#[^#]/  { next }         # Kommentarzeilen direkt unter den Interface-Zeilen
    imBlock && /^#$/     { next }
    { imBlock = 0; print }
  '
}

toc_filter() {  # $1 = Rolle (kern|stimme); liest stdin, schreibt stdout
  awk -v rolle="$1" '
    /^## X-(License|Website|Curse-Project-ID|Wago-ID|WoWI-ID):/ {
      if (!erledigt) {
        if (rolle == "kern") {
          print "## X-License: MIT (code) / GPLv3 (Lyra_Gestalt_Daten) / ARR (art, voice) - see LICENSE and LICENSE-ASSETS.md"
          print "## X-Website: https://github.com/Eumelpriester/lyra-companion"
          # 22.09.2026: beide Projekte angelegt und freigegeben - CurseForge 1703906 (Approved 22.09.),
          # Wago nKWwdoKE (Projekt angelegt 22.09., Upload per ops/wago-upload.sh). Die Zeilen stehen
          # damit scharf; der Packager (Release-Workflow) laedt nur mit gesetzten Secrets hoch.
          print "## X-Curse-Project-ID: 1703906"
          print "## X-Wago-ID: nKWwdoKE"
          print "# ## X-WoWI-ID: 26123"
        } else {
          print "## X-License: MIT (code) / ARR (voice) - see Lyra_Gestalt/LICENSE and Lyra_Gestalt/LICENSE-ASSETS.md"
          print "## X-Website: https://github.com/Eumelpriester/lyra-companion"
        }
        erledigt = 1
      }
      next
    }
    { print }
  '
}

# aufbereiten(): schreibt die auszuliefernde Fassung von $1 nach $3.
# Exit 1 = keine Aufbereitung noetig, Quelldatei 1:1 kopieren.
# Pakete/Daten behaelt seine eigenen Felder (X-License: GPLv3, X-Website: Deathlog).
aufbereiten() {  # $1 = Zielpfad (relativ), $2 = Quelldatei, $3 = Ausgabedatei
  case "$1" in
    Lyra_Gestalt.toc)
      toc_filter kern < "$2" > "$3" ;;
    Pakete/Stimme_de/Lyra_Gestalt_Stimme_de.toc|Pakete/Stimme_en/Lyra_Gestalt_Stimme_en.toc)
      toc_filter stimme < "$2" > "$3" ;;
    *) return 1 ;;
  esac
}

# --- find-Aufruf aus den Ausschlusslisten bauen -----------------------------
find_liste() {  # $1 = Wurzel; gibt Pfade relativ zu $1 aus, sortiert
  local wurzel="$1"
  local -a args=()
  local d n
  for d in "${AUSSCHLUSS_ORDNER[@]}"; do args+=( -name "$d" -prune -o ); done
  args+=( -type f )
  for n in "${AUSSCHLUSS_NAMEN[@]}"; do args+=( ! -name "$n" ); done
  args+=( -print )
  ( cd "$wurzel" && find . "${args[@]}" | sed 's|^\./||' | LC_ALL=C sort )
}

# --- Arbeitsliste: Zielpfad <TAB> Quellpfad ---------------------------------
NEU="$TMP/neu"; : > "$NEU"

for eintrag in "${PAKETE[@]}"; do
  quell_ordner="${eintrag%%|*}"
  ziel_praefix="${eintrag##*|}"
  src="$QUELLE/$quell_ordner"
  [ -d "$src" ] || { echo "WARNUNG: $src fehlt, uebersprungen" >&2; continue; }
  while read -r rel; do
    [ -n "$rel" ] || continue
    if [ "$ziel_praefix" = "." ]; then zp="$rel"; else zp="$ziel_praefix/$rel"; fi
    printf '%s\t%s\n' "$zp" "$src/$rel" >> "$NEU"
  done < <(find_liste "$src")
done

# CHANGELOG.md ausdruecklich (faellt sonst unter den *.md-Ausschluss).
# Der Packager liest es ueber .pkgmeta/manual-changelog fuer das CF-Changelog-Feld.
if [ -f "$QUELLE/CHANGELOG.md" ]; then
  printf '%s\t%s\n' "CHANGELOG.md" "$QUELLE/CHANGELOG.md" >> "$NEU"
else
  echo "WARNUNG: $QUELLE/CHANGELOG.md fehlt" >&2
fi
# CHANGELOG.en.md ebenso (seit 20.09.2026: englische Fassung, die Website liest sie fuer /en/).
if [ -f "$QUELLE/CHANGELOG.en.md" ]; then
  printf '%s\t%s\n' "CHANGELOG.en.md" "$QUELLE/CHANGELOG.en.md" >> "$NEU"
fi

LC_ALL=C sort -o "$NEU" "$NEU"

# --- Spiegeln ---------------------------------------------------------------
n_neu=0; n_geaendert=0; n_gleich=0; n_weg=0

while IFS=$'\t' read -r zp sp; do
  ziel="$ZIEL/$zp"
  fassung="$sp"
  if aufbereiten "$zp" "$sp" "$TMP/aufbereitet" 2>/dev/null; then
    fassung="$TMP/aufbereitet"
  fi
  if [ ! -f "$ziel" ]; then
    echo "  + $zp"
    ABWEICHUNG=1; n_neu=$((n_neu+1))
    [ "$MODUS" = check ] || { mkdir -p "$(dirname "$ziel")"; cp "$fassung" "$ziel"; }
  elif ! cmp -s "$fassung" "$ziel"; then
    echo "  M $zp"
    ABWEICHUNG=1; n_geaendert=$((n_geaendert+1))
    [ "$MODUS" = check ] || cp "$fassung" "$ziel"
  else
    n_gleich=$((n_gleich+1))
  fi
done < "$NEU"

# --- Verwaiste Dateien aus dem alten Manifest ------------------------------
# Mengenvergleich ueber comm statt grep-je-Zeile: ein Durchlauf, und kein
# "cut | grep -q"-Rohr (grep -q beendet sich sofort, cut stirbt an SIGPIPE,
# und mit 'set -o pipefail' haette jede Zeile faelschlich als verwaist gegolten).
cut -f1 "$NEU" > "$TMP/neukeys"
if [ -f "$MANIFEST" ]; then
  { grep -v '^[[:space:]]*#' "$MANIFEST" || true; } | { grep -v '^[[:space:]]*$' || true; } \
    | LC_ALL=C sort -u > "$TMP/altkeys"
  while read -r alt; do
    [ -n "$alt" ] || continue
    [ -e "$ZIEL/$alt" ] || continue
    echo "  - $alt"
    ABWEICHUNG=1; n_weg=$((n_weg+1))
    [ "$MODUS" = check ] || rm -f "$ZIEL/$alt"
  done < <(LC_ALL=C comm -13 "$TMP/neukeys" "$TMP/altkeys")
fi

# --- Flavor-TOC erzeugen ----------------------------------------------------
# Lyra_Gestalt_Vanilla.toc ist eine ERZEUGTE Kopie der (schon aufbereiteten)
# Basis-TOC, damit die 40-zeilige Dateiliste nicht doppelt gepflegt werden muss.
# Der Classic-Era-Client bevorzugt sie vor Lyra_Gestalt.toc.
#
# PORT 0.9.0: Seit die Basis-TOC "## Interface-<Typ>:"-Zeilen traegt und .pkgmeta
# "enable-toc-creation: yes" steht, erzeugt der PACKAGER beim Paketieren zusaetzlich
# _Vanilla/_TBC/_Mists/_Mainline und schreibt seine Fassung ueber diese Datei.
# Diese hier bleibt trotzdem: sie liegt im REPO (nicht nur im Zip), ist der getestete
# Era-Stand und geht auch in ein von Hand gebautes Zip mit (tools/dist-bauen.sh).
# Damit beide Fassungen nicht auseinanderlaufen, laeuft sie jetzt zusaetzlich durch
# flavor_filter (siehe oben) und ist damit genau das, was der Packager auch erzeugt:
# dieselbe Dateiliste, "## Interface: 11509", keine Interface-<Typ>-Zeilen.
BASIS_TOC="$ZIEL/Lyra_Gestalt.toc"
FLAVOR_TOC="$ZIEL/Lyra_Gestalt_Vanilla.toc"
if [ -f "$QUELLE/Lyra_Gestalt/Lyra_Gestalt.toc" ]; then
  erz="$TMP/vanilla.toc"
  # RECHERCHE-11 (20.09.2026): Die ERSTE Zeile einer TOC muss eine "## "-Direktive sein.
  # warcraft.wiki.gg/Patch_12.0.7/API_changes: "TOC files will skip loading all directives if
  # the first line starts with a comment (a single #)." Classic Era bevorzugt genau diese
  # Datei - mit einem Kommentar in Zeile 1 haette der Client weder Interface noch Dateiliste
  # gelesen. Deshalb: erst die Direktiven, die Erklaerung danach (Kommentare hinter der
  # letzten Direktive sind unproblematisch).
  toc_filter kern < "$QUELLE/Lyra_Gestalt/Lyra_Gestalt.toc" | flavor_filter > "$erz"
  {
    echo ""
    echo "# ERZEUGT von tools/release-sync.sh aus Lyra_Gestalt.toc - nicht von Hand editieren."
    echo "# Classic Era / Hardcore 1.15.9. Der Client bevorzugt diese Datei vor Lyra_Gestalt.toc."
    echo "# Die \"## Interface-<Typ>:\"-Zeilen der Basis-TOC sind hier absichtlich entfernt -"
    echo "# in einer TOC MIT Suffix gilt nur die eigene \"## Interface:\"-Zeile."
    echo "# Kommentare stehen absichtlich am ENDE: Zeile 1 muss eine ## -Direktive sein (12.0.7)."
  } >> "$erz"
  if [ ! -f "$FLAVOR_TOC" ] || ! cmp -s "$erz" "$FLAVOR_TOC"; then
    echo "  * Lyra_Gestalt_Vanilla.toc (erzeugt)"
    ABWEICHUNG=1
    [ "$MODUS" = check ] || cp "$erz" "$FLAVOR_TOC"
  fi
fi

# --- Leere Ordner aufraeumen ------------------------------------------------
if [ "$MODUS" != check ]; then
  find "$ZIEL" -mindepth 1 -type d -empty \
    ! -path "$ZIEL/.git/*" ! -path "$ZIEL/.github/*" ! -path "$ZIEL/docs/*" \
    -delete 2>/dev/null || true
fi

# --- Manifest schreiben -----------------------------------------------------
if [ "$MODUS" != check ]; then
  {
    echo "# erzeugt von tools/release-sync.sh - Liste aller aus addon/ gespiegelten Pfade."
    echo "# Nicht von Hand editieren. Dient dem Loeschen verwaister Dateien beim naechsten Lauf."
    cat "$TMP/neukeys"
  } > "$MANIFEST"
fi

gesamt=$(wc -l < "$NEU")
echo "----"
echo "Quelle : $QUELLE"
echo "Ziel   : $ZIEL"
printf 'Dateien: %s gespiegelt (neu %s, geaendert %s, unveraendert %s, verwaist %s)\n' \
  "$gesamt" "$n_neu" "$n_geaendert" "$n_gleich" "$n_weg"

if [ "$MODUS" = check ]; then
  if [ "$ABWEICHUNG" -ne 0 ]; then
    echo "ABWEICHUNG - 'tools/release-sync.sh' ohne --check ausfuehren."
    exit 1
  fi
  echo "Release-Layout ist auf dem Stand von addon/."
fi
