# Regeln

## Code

- Niemals raten (siehe No-Guess-Vertrag in `AGENTS.md`).
- Zielplattform ist ausschliesslich WoW Forever (`1.60.x`, Interface `16001`); kein
  Kompatibilitaetscode fuer andere Clients.
- Jeder API-Aufruf laeuft ueber `call()` (Typpruefung + `pcall`); fehlende APIs fallen still weg.
- Geheime Werte werden vor jeder anderen Operation geprueft; mit ihnen wird nie gerechnet,
  verglichen oder verkettet (Details in `CLAUDE.md`).
- Slash-Befehle bleiben rueckwaertskompatibel, ausser es wird explizit geaendert.
- Additive Aenderungen vor breaking Refactors bevorzugen.

## Lokalisierung

- Alle sichtbaren Texte laufen ueber `ns.L` (`Locale.lua`).
- Jeder neue Text wird auf Englisch und Deutsch gepflegt; `tools/check_locale.lua` prueft, dass
  beide Tabellen dieselben Schluessel haben.
- Nicht unterstuetzte Locales fallen auf Englisch zurueck.
- Spielbegriffe folgen dem deutschen Client (z. B. "Abgewehrte Schlaege" fuer Glancing Blows,
  "Schlachtzugsboss").

## Performance

- Keine Arbeit in `OnUpdate`; einzige Ausnahme ist das Ziehen am Groessen-Griff.
- Refreshes laufen nur bei sichtbarem Fenster und werden gebuendelt (`RequestRefresh`, 0,15 s).
- Events werden beim Login registriert, nicht dynamisch aus Event-Handlern.

## UI

- Farben nur ueber die Palette `C` in `UI.lua` (isiLive-Modern-Stil: Graphit, feine Linien,
  kuehles Blau). Kein Gold-Glow, keine Skalierungs-Animationen.
- Hintergrund-Transparenz betrifft nur Flaechen, nie die Schrift.
- Status nicht nur ueber Farbe vermitteln, wo es um Entscheidungen geht (Tooltip ergaenzt).

## Dokumentation

- `README.md` wird bei jeder sichtbaren Verhaltensaenderung aktualisiert (Features, Befehle).
- `CHANGELOG.md` wird bei jeder funktionalen Aenderung unter `## Unreleased` ergaenzt; beim Release
  bekommt der Abschnitt Version und Datum im Format `YYYY-MM-DD`.
- `docs/curseforge.md` bleibt synchron zur README, wenn sich Features aendern.
