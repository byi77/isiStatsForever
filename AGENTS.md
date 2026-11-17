# AGENTS

Regeln fuer Agenten in isiStats (angepasst aus isiLive). Technische Details stehen in `CLAUDE.md`,
allgemeine Coding-Regeln in `docs/RULES.md`.

## No-Guess-Vertrag

- Niemals raten.
- Niemals spekulative Fallbacks bauen.
- Ein Wert, der nicht direkt aus einer belastbaren Quelle stammt, gilt als unbekannt: Zeile
  ausblenden, `??` anzeigen oder (im Kampf) den letzten echten Wert ausgegraut zeigen - nie einen
  geschaetzten Wert als echt darstellen.
- Erlaubte Quellen: Live-Werte der WoW-API, die Anzeige im Spiel (Fertigkeitenfenster, Tooltips)
  und eindeutig dokumentierte Benutzerentscheidungen.
- Fehlt eine belastbare Quelle, stoppe, benenne die Luecke konkret und frage den User gezielt
  (z. B. nach einem Screenshot des Spielfensters oder der Ausgabe von `/isistats debug`).

## Dokument- und Verzeichnisstruktur

- `README.md` - Features, Befehle, Entwicklung (Englisch)
- `CHANGELOG.md` - Changelog, oben `## Unreleased` (Englisch)
- `CLAUDE.md` - technische Projektregeln (Englisch)
- `AGENTS.md` - diese Datei
- `docs/RULES.md` - allgemeine Coding-, Doku- und UI-Regeln
- `docs/curseforge.md` - Vorlage fuer die CurseForge-Projektseite
- `docs/logo.svg`, `docs/logo.png` - Logo; `media/icon.tga` - Icon in der Addon-Liste
- `tools/` - Pruefwerkzeuge (nicht im Release-Zip)

## Sprachregel

- Chat-Antworten immer auf Deutsch, jede einzelne.
- Code und Code-Kommentare auf Englisch.
- `README.md` und `CHANGELOG.md` Englisch, alle anderen Dokus Deutsch.

## Verbindliche Validierung

Vor dem Abschliessen einer Aenderung muessen alle Pruefungen aus `CLAUDE.md` gruen sein
(stylua, luacheck, Locale-Check, Ladetest). Schlaegt eine fehl, wird nicht abgeschlossen, bis die
Ursache behoben ist. Ingame-Verhalten, das nicht im Spiel geprueft wurde, wird dem User als
"nicht ingame getestet" gemeldet.

## Release

Kein Release, kein Tag und kein CurseForge-Upload ohne ausdrueckliche Ansage des Users.
Committen und auf `main` pushen ist erlaubt.
