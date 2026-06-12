# Kalenderplanung: Serien, Erinnerungen & Redesign — Design Spec

**Datum:** 2026-06-13
**Status:** Entwurf (vom Nutzer per Brainstorming validiert)

## Ziel

Der Kalender-Bereich wird vom rohen Monats-Grid zur Trainings-Kommandozentrale ausgebaut:

1. **Serien**: Wiederkehrende Trainings regelbasiert anlegen (z.B. jede Woche Di/Do/Sa).
2. **Erinnerungen**: Optionale lokale Benachrichtigung an Trainingstagen zu einer globalen Uhrzeit.
3. **Notiz**: Ein freies Notizfeld pro Tag (ersetzt die zwei Ernährungsfelder).
4. **Workout-Kopplung**: Heute geplantes Training mit einem Tap im Workout-Screen aktivieren.
5. **Visuelles Redesign**: Kalender-Screen im Stil „Monat + Agenda" (Variante A), Tag-Editor mit Plan-Auswahl als vertikale Liste (Variante A).

## Getroffene Entscheidungen

| Frage | Entscheidung |
|---|---|
| Serien-Modell | Regel-basiert: Serie = Plan + Wochentage, gilt unendlich ab Startdatum; einzelne Tage über­schreibbar/ausnehmbar |
| Benachrichtigung | Globale Uhrzeit in den Einstellungen (Default 08:00), ein Toggle für alle Trainingstage |
| Tageskommentar | Ein freies Notizfeld statt „Ernährung Vortag/Nachtag" |
| Workout-Kopplung | Hinweis + 1-Tap (kein automatischer Planwechsel) |
| Kalender-Layout | Variante A: kompaktes Monatsgrid oben + „Anstehend"-Agenda darunter, Heute-Karte mit Start-Button |
| Plan-Auswahl im Editor | Variante A: vertikale Liste — jeder Plan eine Zeile mit Eckdaten und Radio-Ring, scrollbar |

## Datenmodell

### Neu: `TrainingSeries` (`lib/core/models/training_series.dart`)

```dart
class TrainingSeries {
  final String id;            // uuid-artig, wie TrainingPlan.id
  final String planId;        // referenziert TrainingPlan.id
  final Set<int> weekdays;    // 1=Mo … 7=So (DateTime.weekday)
  final DateTime startDate;   // ab wann die Serie gilt (nur Datum)
  final Set<String> exceptions; // ISO-Daten 'yyyy-MM-dd' ausgenommener Tage
}
```

Persistenz: `SeriesStorage` analog `CalendarStorage`, SharedPreferences-Key `trainingSeries`, JSON-Liste mit Kurz-Keys (`id`, `p`, `wd`, `s`, `ex`).

### Geändert: `CalendarEntry`

- `preNutrition` + `postNutrition` werden zu einem Feld `note`.
- **Migration** in `fromJson`: enthält das JSON noch `pre`/`post`, werden beide non-empty-Werte mit Zeilenumbruch zu `note` zusammengeführt. `toJson` schreibt nur noch `n` (note, wenn nicht leer).

### Tages-Auflösung (pure Funktion, `lib/core/models/planned_day.dart`)

```dart
PlannedDay? resolveDay(DateTime date, List<CalendarEntry> entries, List<TrainingSeries> series);

class PlannedDay {
  final String planId;
  final String note;        // bei Serientag ohne Override: ''
  final bool fromSeries;
  final String? seriesId;
}
```

Regeln (Vorrang absteigend):

1. Einzeleintrag (`CalendarEntry`) am Datum → gewinnt immer (auch als Override eines Serientags).
2. Serie, deren `weekdays` den Wochentag enthält, `startDate <= date` und Datum nicht in `exceptions` → Treffer. Bei mehreren passenden Serien gewinnt die zuletzt angelegte.
3. Sonst: kein Training (max. ein Training pro Tag).

## Provider

- **Neu `SeriesNotifier`** (`lib/core/providers/series_notifier.dart`, Riverpod `keepAlive`): lädt `SeriesStorage`, Methoden `addSeries`, `removeSeries`, `addException(seriesId, date)`.
- `CalendarNotifier` bleibt; `entryFor` bleibt für Einzeleinträge.
- Die Screens kombinieren beide Provider über `resolveDay` (kein eigener kombinierter Provider nötig).

## UI

### Kalender-Screen (Redesign, „Monat + Agenda")

- **Header**: Monatsname groß + Jahr gedimmt links (`Juni 2026`), `‹ ›`-Navigation rechts. AppBar-Back-Chevron zum Workout-Screen bleibt.
- **Monatsgrid** (kompakt): 
  - Heute = gefüllter oranger Kreis mit schwarzer Zahl (statt nur Rahmen).
  - Einzeleintrag = voller oranger Punkt, Serientag = gedimmter oranger Punkt (45 % Opacity), Override eines Serientags = voller Punkt.
  - Vergangene Tage gedimmt wie bisher. Tap auf Tag öffnet Tag-Editor.
- **Agenda „ANSTEHEND"** unter dem Grid (gemeinsam scrollbar):
  - Zeigt die geplanten Trainings der nächsten 14 Tage (inkl. heute), aufgelöst über `resolveDay`.
  - **Heute-Karte** (wenn heute Training geplant): hervorgehoben mit orangem Gradient/Border; zeigt `HEUTE · FR 13. JUNI`, Planname, Serie-Badge (`🔁 Di/Do/Sa`), Erinnerungszeit (`🔔 08:00`, nur wenn Erinnerung aktiv), Notiz-Preview und Button **„▶ Training starten"** → aktiviert den Plan (siehe Workout-Kopplung) und navigiert zur Workout-Seite.
  - **Folge-Karten**: gedimmter, eine Zeile Datum-Label + Planname + Serie-Icon + Notiz-Preview. Tap öffnet den Tag-Editor des Tags.
  - Keine geplanten Trainings → Leerzustand mit Hinweis („Tippe auf einen Tag, um ein Training zu planen").

### Tag-Editor (Bottom Sheet, überarbeitet)

- **Header**: Datum; bei Serientag zusätzlich Badge `🔁 SERIE · DI/DO/SA`.
- **Plan-Auswahl (vertikale Liste)**: Jeder Plan eine Zeile mit Name + Eckdaten (Minuten, Equipment-Kurzlabels) und Radio-Ring rechts; der gewählte Plan ist orange hervorgehoben. Die Liste zeigt max. ~4 Zeilen und scrollt intern bei mehr Plänen. Speichern bleibt ohne Plan-Auswahl deaktiviert.
- **Serien-Toggle** `🔁 Wöchentlich wiederholen` (nur bei Neuanlage oder bestehendem Einzeleintrag, **nicht** bei Serientag): aktiviert eingeblendete Wochentag-Kreise Mo–So, der Wochentag des geöffneten Tags ist vorausgewählt. Speichern mit Toggle an → legt `TrainingSeries` an (startDate = geöffneter Tag, Notiz wird als Tages-Override nur gespeichert, wenn nicht leer). War der Tag vorher ein Einzeleintrag, wird dieser entfernt und durch die Serie ersetzt.
- **Notizfeld**: ein mehrzeiliges Feld „Notiz" (Hint: „z.B. Ernährung: abends Kohlenhydrate auffüllen").
- **Aktionen**:
  - Normaler Tag: „Speichern", optional „Eintrag entfernen".
  - Serientag: „Speichern" (erzeugt Einzeleintrag-Override nur für diesen Tag, Hinweistext „Änderungen gelten nur für diesen Tag"), „Diesen Tag ausnehmen" (fügt Exception hinzu), „Serie löschen" (rot, mit Bestätigungs-Dialog; entfernt die Regel und damit alle zukünftigen Serientage, vorhandene Overrides/Einzeleinträge bleiben).

### Workout-Screen (Kopplung)

- Ist für heute ein Training aufgelöst und dessen Plan ≠ aktiver Plan: dezenter Chip „Heute geplant: \<Planname\>" (Position: unter dem bestehenden PlanIndicator). Tap aktiviert den Plan über den bestehenden Plan-Wechsel-Mechanismus (inkl. Reset-Bestätigung, falls ein Workout aktiv ist). Ist der geplante Plan bereits aktiv, kein Chip.
- Der „▶ Training starten"-Button der Heute-Karte nutzt denselben Pfad: Plan aktivieren + `animateToPage(AppPage.workout)`.

### Einstellungen (Feedback-Tab)

- Neue Sektion „Erinnerung": Toggle **„Trainings-Erinnerung"** + Uhrzeit-Picker (`showTimePicker`, Default 08:00). Neue `AppSettings`-Felder: `trainingReminderEnabled` (bool, default false), `trainingReminderMinutes` (int, Minuten seit Mitternacht, default 480).

## Benachrichtigungen

- **Neue Dependencies**: `flutter_local_notifications`, `timezone` (+ `flutter_timezone` für die lokale Zone).
- **Neu `NotificationService`** (`lib/core/services/notification_service.dart`):
  - `rescheduleAll(settings, entries, series, plans)`: storniert alle geplanten Notifications und plant für die nächsten **30 Tage** jeden aufgelösten Trainingstag eine Notification zur globalen Uhrzeit. Titel „Training geplant", Body „Heute geplant: \<Planname\>".
  - Wird aufgerufen: beim App-Start und nach jeder Änderung an Kalendereinträgen, Serien oder den Reminder-Settings. Rollierendes Fenster nötig, weil Serien unendlich sind.
  - Die Terminberechnung (welche Tag/Zeit-Paare geplant werden) ist eine pure Funktion und wird separat getestet.
- **Android**: `POST_NOTIFICATIONS`-Permission wird beim Aktivieren des Toggles angefragt (Toggle bleibt aus, wenn abgelehnt). Inexakte Planung (`AndroidScheduleMode.inexactAllowWhileIdle`) — keine Exact-Alarm-Sonderberechtigung nötig.

## Tests

- `TrainingSeries`: toJson/fromJson-Roundtrip, Defaults.
- `CalendarEntry`: Migration `pre`/`post` → `note`, neuer Roundtrip.
- `resolveDay`: Einzeleintrag schlägt Serie; Serie greift nur an Wochentagen ab startDate; Exceptions; jüngste Serie gewinnt bei Kollision.
- Notification-Terminberechnung: korrekte Tage/Uhrzeit im 30-Tage-Fenster, keine Termine in der Vergangenheit, leer bei deaktiviertem Toggle.

## Nicht im Scope (YAGNI)

- Serie nachträglich bearbeiten (Wochentage/Plan ändern) → löschen + neu anlegen.
- Uhrzeit pro Eintrag / pro Serie.
- Mehrere Trainings pro Tag.
- Zweiwöchentliche o.ä. Rhythmen (nur wöchentlich).
