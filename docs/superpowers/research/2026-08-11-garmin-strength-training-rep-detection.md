# Garmin Strength-Training-Wiederholungszählung: Ist sie aus einer eigenen Connect-IQ-App nutzbar?

**Datum:** 2026-08-11
**Kontext:** emom_app hat bereits eine Connect-IQ-Companion-App (`garmin_watch_app/`) und einen Phone↔Watch-Rückkanal.
Frage: Kann die native Rep-Erkennung des Garmin-Aktivitätsprofils "Fitnessstudio → Freies Training"
(Strength Training) irgendwie in die eigene Watch-App integriert oder von ihr ausgelesen werden?
**Methode:** Ausschließlich Primärquellen (developer.garmin.com API-Referenz, FIT-SDK-Profil aus Garmins
eigenem GitHub-Repo, Garmin-Connect-Developer-Program-Seiten), Foren nur als Korroboration.

---

## Kurzfassung

**Nein — der native Rep-Counting-Algorithmus ist über keine öffentliche Garmin-API zugänglich, weder live
noch nachträglich auf der Uhr.** Die vollständige Connect-IQ-API-Klassenliste enthält keine einzige Klasse
oder Konstante für Sätze/Wiederholungen; `Activity.Info` (die einzige Live-Datenquelle für laufende
Aktivitäten) hat 48 dokumentierte Member, von denen keiner Reps/Sets betrifft; `ActivityRecording.Session`
kennt `addLap()`, aber kein `addSet()`; und `FitContributor` darf Developer-Felder ausschließlich an die
FIT-Messages `SESSION` (18), `LAP` (19) und `RECORD` (20) hängen — nicht an die `SET`-Message (225), in der
Garmin die Wiederholungen tatsächlich ablegt. Was **geht**: (a) rohe Beschleunigungsdaten (x/y/z in Milli-G,
Sample-Rate gerätespezifisch) via `Sensor.registerSensorDataListener()` — d.h. eine *eigene* Rep-Erkennung
ist technisch möglich, aber Garmin liefert dafür weder Beispielcode noch Dokumentation; und (b) nachträglich
das *Original-FIT-File* inklusive `SET`-Messages über die Garmin Activity API — die aber laut Garmins
eigener FAQ "only for business use" ist. Für emom_app als privates Projekt heißt das praktisch: entweder
selbst zählen, oder die native Aktivität parallel laufen lassen und die Daten nur in Garmin Connect ansehen.

---

## 1. Ist der native Rep-Counting-Algorithmus über eine öffentliche API exponiert?

### Direkte Antwort

**Nein.** Es gibt keinen dokumentierten Weg, den Wiederholungszähler des nativen Strength-Training-Profils
aus einer Connect-IQ-App zu lesen — weder live während der Aktivität noch nachträglich vom Gerät.
Zusätzlich gibt es auch keinen Weg, eigene Rep-/Satz-Werte so zu *schreiben*, dass Garmin Connect sie als
Sätze anzeigt.

### Evidenz

**(a) `Toybox.Activity.Info` — die einzige Live-Quelle für Aktivitätsdaten — hat keinerlei Rep-Feld.**
Vollständige Member-Liste laut
<https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/Info.html>:
`altitude, ambientPressure, averageCadence, averageDistance, averageHeartRate, averagePower, averageSpeed,
bearing, bearingFromStart, calories, currentCadence, currentHeading, currentHeartRate, currentLocation,
currentLocationAccuracy, currentOxygenSaturation, currentPower, currentSpeed, distanceToDestination,
distanceToNextPoint, elapsedDistance, elapsedTime, elevationAtDestination, elevationAtNextPoint,
energyExpenditure, frontDerailleurIndex, frontDerailleurMax, frontDerailleurSize, maxCadence, maxHeartRate,
maxPower, maxSpeed, meanSeaLevelPressure, nameOfDestination, nameOfNextPoint, offCourseDistance,
rawAmbientPressure, rearDerailleurIndex, rearDerailleurMax, rearDerailleurSize, startLocation, startTime,
swimStrokeType, swimSwolf, timerState, timerTime, totalAscent, totalDescent, track, trainingEffect`.
Bemerkenswert: Für **Schwimmen** existieren sehr wohl sportartspezifische Auswertungsfelder
(`swimStrokeType`, `swimSwolf`, `averageDistance` = "The average swim stroke distance from the previous
interval in meters (m)"). Für Krafttraining existiert das Äquivalent nicht. Das ist ein starkes Indiz,
dass die Auslassung Absicht ist und kein Doku-Lücke.

**(b) Die komplette Connect-IQ-Klassenliste enthält keine Set-/Rep-/Strength-Klasse.**
Grep über <https://developer.garmin.com/connect-iq/api-docs/class_list.html> nach
`Set|Rep|Strength|Exercise|Workout` liefert als Treffer nur:
`Toybox.Activity.WorkoutStep`, `Toybox.Activity.WorkoutIntervalStep`, `Toybox.Activity.WorkoutStepInfo`,
`Toybox.PersistedContent.Workout` sowie diverse `*Settings`-Klassen (`DeviceSettings`, `UserSettings`,
`ResistanceSettings`, …), die mit Krafttraining nichts zu tun haben.

**(c) `Activity.WorkoutStep` liefert nur die *vorgegebene* Zielwiederholungszahl, nicht die gezählte.**
Instance-Variablen laut <https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/WorkoutStep.html>:
`durationType`, `durationValue`, `targetType`, `targetValueHigh`, `targetValueLow` — mehr nicht.
`Toybox.Activity` definiert dazu die Konstante `WORKOUT_STEP_DURATION_REPS` (Wert 29, API Level 3.2.0), d.h.
ein Schritt eines strukturierten Workouts *kann* "X Wiederholungen" als Dauer haben, und
`Activity.getCurrentWorkoutStep()` ("Get information about the current workout step.", API Level 3.2.0)
gibt diese Vorgabe zurück. Der **Ist-Wert** — was die Uhr tatsächlich gezählt hat — ist nirgends abrufbar.

**(d) `ActivityRecording.Session` hat kein `addSet()`.**
Vollständige Instance-Methoden laut
<https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording/Session.html>:
`addLap()`, `createField()`, `discard()`, `isRecording()`, `save()`, `setTimerEventListener()`, `start()`,
`stop()`. Kein Set-/Rep-Konstrukt.

**(e) `FitContributor` kann Developer-Felder nur an drei FIT-Message-Typen hängen — `SET` ist nicht dabei.**
<https://developer.garmin.com/connect-iq/api-docs/Toybox/FitContributor.html> definiert genau drei
`MESG_TYPE_*`-Konstanten: `MESG_TYPE_SESSION` = 18, `MESG_TYPE_LAP` = 19, `MESG_TYPE_RECORD` = 20.
Die FIT-`SET`-Message hat global-mesg-num **225** (siehe Abschnitt 5) und ist damit für Connect IQ nicht
adressierbar — weder lesend noch schreibend.

**(f) Das Setzen von `SUB_SPORT_STRENGTH_TRAINING` aktiviert die native Erkennung nicht garantiert.**
`Toybox.ActivityRecording` kennt zwar `SPORT_TRAINING` (Wert 10, "Sport used for activities such as strength
training, cardio, etc") und `SUB_SPORT_STRENGTH_TRAINING` (Wert 20, seit API Level 1.0.0). Aber die
Modul-Doku schränkt ausdrücklich ein
(<https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording.html>):

> "The SPORT_* defines the type of activity, but is not guaranteed to change device behavior. This may cause
> different algorithms to be applied to the sensor data. For example, a device that does not natively support
> SPORT_MULTISPORT recording will not gain SPORT_MULTISPORT transition features."

Also: *"may cause different algorithms to be applied"* — keine Zusage. Und selbst wenn der Rep-Algorithmus
liefe, gäbe es nach (a)–(e) keine API, um sein Ergebnis zu lesen oder in die FIT-Datei zu bekommen.

**(g) Eine Connect-IQ-App kann auch die fertige FIT-Datei nicht auf dem Gerät lesen.**
`Toybox.PersistedContent` (<https://developer.garmin.com/connect-iq/api-docs/Toybox/PersistedContent.html>)
ist die einzige Datei-/Content-Zugriffsschicht und deckt laut Overview nur diese Typen ab:

> "Included content types are as follows: Course, Route, Track, Waypoint, Workout"

Aufgezeichnete Aktivitäts-FIT-Dateien sind nicht dabei.

**(h) Korroboration aus dem Connect-IQ-Forum (keine Garmin-Mitarbeiter, s. "Was nicht auffindbar war"):**
Thread "Need a better Activity API"
(<https://forums.garmin.com/developer/connect-iq/f/discussion/280011/need-a-better-activity-api>).
Nutzer *flowstate*: "Adding laps to a Strength Training activity via CIQ is not the same as adding sets
natively. They won't show up as sets in Garmin Connect." — und schlägt als *Feature Request* vor:
"Implement addSet() (with reps and weight) in the CIQ API". Nutzer *jim_m_58*: "There is no option to do
anything different in CIQ than what I proposed, and the chances of that changing are next to nil."

### Sicherheit

**Verifiziert aus Primärquelle** — allerdings als Negativbefund: Ich habe die vollständige, dokumentierte
API-Oberfläche (Klassenliste, `Activity.Info`, `ActivityRecording.Session`, `FitContributor`,
`PersistedContent`) durchsucht und nichts gefunden. Das beweist die Abwesenheit einer *dokumentierten* API.
Undokumentiertes Verhalten kann ich damit formal nicht ausschließen — es gibt aber auch keinerlei Hinweis
darauf.

---

## 2. Welche Rohsensordaten stehen Drittanbieter-Apps in Echtzeit zur Verfügung?

### Direkte Antwort

**Echte Roh-Beschleunigungsdaten (x/y/z, einzelne Samples) sind verfügbar** — über
`Sensor.registerSensorDataListener()`, seit API Level 2.3.0, auch auf der Venu 4. Die maximale Sample-Rate
ist gerätespezifisch und wird zur Laufzeit abgefragt, nicht in der Doku genannt. Wichtige Einschränkung:
**nicht aus einer Data-Field-App heraus** — dort stürzt der Aufruf ab.

### Evidenz

**Quelle: <https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor.html>**

Signatur-Optionen von `registerSensorDataListener(listener, options)`:

- `:period` — "Period of time to request samples in seconds. **Maximum is 4 seconds.**"
- `:accelerometer => { :enabled, :sampleRate, :includePower, :includePitch, :includeRoll, :includeTimestamps }`
  - `:sampleRate` — "Samples per second to request in Hz." (**kein dokumentiertes Maximum an dieser Stelle**)
- `:gyroscope => { :enabled, :sampleRate, :includeTimestamps }`
- `:magnetometer => { :enabled, :sampleRate, :includeTimestamps }`
- `:heartBeatIntervals => { :enabled }`
- `:synchronous` — "Set to `true` to request synchronized sensor data."

Offizielles Beispiel aus derselben Seite:

```monkeyc
var options = {
    :period => 1,               // 1 second sample time
    :accelerometer => {
        :enabled => true,       // Enable the accelerometer
        :sampleRate => 25       // 25 samples
    },
    :heartBeatIntervals => { :enabled => true }
};
Sensor.registerSensorDataListener(method(:accelCallback), options);
```

(Die 25 Hz sind Garmins *Beispielwert*, nicht ein dokumentiertes Maximum.)

- **Since:** "API Level 2.3.0"
- **Exceptions:** `TooManySensorDataListenersException` — "Thrown if more than one listener is tried to
  register for sensor data." → **genau ein Listener gleichzeitig**.
  `Lang.InvalidOptionsException` — "Thrown if any required options are excluded, if provided options are out
  of range, or are of the wrong type."
- **Data-Field-Verbot:** Der Hinweis "Will cause an app crash if called from a data field app" steht
  im HTML-Abschnitt von `registerSensorDataListener` (ebenso bei `enableSensorEvents`, `getMaxSampleRate`
  und `getMaxSampleRateForSensorType`). → Ein Connect-IQ-**Datenfeld**, das man in das native
  Strength-Profil einhängen könnte, hat also *keinen* Zugriff auf Rohbeschleunigung. Rohdaten gibt es nur in
  einer eigenständigen Watch-App — die dann aber ihre eigene Aktivität aufzeichnet, nicht die native.
- **Permission:** Das Modul `Toybox.Sensor` ist mit "Requires Permission: **Sensor**" markiert (muss in
  `manifest.xml` deklariert werden).

**Datenformat — <https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor/AccelerometerData.html>:**

> "A class to store accelerometer sample data. Each field specified is an Array of Float or Number values.
> **The values for the x, y, and z axes are in Milli G units. For reference, 1000 Milli G = 1 G.** If not
> `null`, all fields are of equal size."

Member: `x`, `y`, `z` (Arrays of Number, Milli-G), optional `power` (Number, "vector power values … in
millig-units"), `pitch` (Float, Grad), `roll` (Float, Grad), `timestamp` (Number, Millisekunden).
→ **Echte Rohachsen, nicht nur abgeleitete Werte.**

`Sensor.SensorData` kapselt `accelerometerData`, `gyroscopeData`, `magnetometerData`, `heartRateData`.

**Maximale Sample-Rate:** Es gibt zwei Abfragemethoden, aber **keinen in der Doku genannten Zahlenwert**:

- `getMaxSampleRate()` — "Get the maximum sample rate supported by the system."
- `getMaxSampleRateForSensorType(sensorDataType)` — "Get the maximum sample rate supported for given sensor
  data type." Erlaubte Symbole: "`accelerometer`, `gyroscope`, and `magnetometer`". Beispiel:
  `var maxSample = Sensor.getMaxSampleRateForSensorType(:accelerometer);`
- Bei beiden steht die Notiz: "This function can produce different results after the app transitions to the
  active state after being inactive." → Die Rate ist nicht nur geräte-, sondern auch zustandsabhängig und
  muss zur Laufzeit ermittelt werden.

**Venu-4-Unterstützung:** Im Abschnitt zu `registerSensorDataListener` der Sensor-Seite ist in der
"Supported Devices"-Liste u.a. "Venu® 4 41mm" und "**Venu® 4 45mm / D2™ Air X15**" aufgeführt — also genau
das Zielgerät dieses Projekts.

**Die langsame Alternative — `enableSensorEvents()`:**

> "Sensor events are retrieved from any enabled sensors **at a rate of 1 Hz**."

Since API Level 1.0.0. Liefert ein `Sensor.Info`-Objekt (HR, Kadenz, Temperatur, Druck …) — **keine
Beschleunigungsachsen**. Für Rep-Erkennung nutzlos.

**`Toybox.SensorHistory` enthält keine Beschleunigungshistorie.**
Vollständige Getter laut <https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorHistory.html>:
`getBodyBatteryHistory`, `getElevationHistory`, `getHeartRateHistory`, `getOxygenSaturationHistory`,
`getPressureHistory`, `getStressHistory`, `getTemperatureHistory`. Modul-Overview: "The amount of information
that is available is device dependent. This means that one device may provide more information than another."
→ Kein Accelerometer, keine nachträgliche Rekonstruktion von Bewegungsdaten.

**`Toybox.SensorLogging`** (<https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorLogging.html>,
seit API Level 2.3.0) ist nur zum *Aufzeichnen* gedacht: "Class for the SensorLogger object. This object gets
passed to FIT session to start recording…" — es liefert keine Werte an die App zurück.

### Sicherheit

**Verifiziert aus Primärquelle**, mit einer Ausnahme: der **konkrete Zahlenwert der maximalen
Accelerometer-Sample-Rate auf der Venu 4** ist nicht dokumentiert und lässt sich nur auf dem Gerät bzw. im
Simulator per `getMaxSampleRateForSensorType(:accelerometer)` feststellen. Community-Angaben (typisch 25 Hz)
habe ich **nicht** aus einer Primärquelle bestätigen können.

---

## 3. Gibt es einen dokumentierten Weg, selbst Wiederholungen aus Rohbeschleunigung zu zählen?

### Direkte Antwort

**Technisch ja, offiziell dokumentiert nein.** Die Rohdaten sind da (Abschnitt 2), aber Garmin liefert
weder ein offizielles Sample, noch einen Core-Topics-Guide, noch einen Blogpost, noch eine von
Garmin-Mitarbeitern bestätigte Forum-Aussage zum Thema Rep-Erkennung. Wer das will, schreibt den Algorithmus
komplett selbst.

### Evidenz

**(a) Garmins offizielles Sample-Repo enthält kein Accelerometer-/Rep-Beispiel.**
<https://github.com/garmin/connectiq-apps>, vollständiger Top-Level-Inhalt via GitHub-API:
`audio-provider`, `barrels`, `datafields`, `device-apps`, `watchfaces`, `widgets`, `README.md`, `LICENSE.md`.
Darin:
- `datafields/` → nur `GenericAntPlusHeartRateField`
- `device-apps/` → `bluetooth-mesh-sample`, `disc-golf`, `lidar-theremin`, `namaste`

Kein Sensor-/Accelerometer-/Strength-Sample.

**(b) Der Core-Topics-Guide "Sensors" ließ sich nicht auslesen.**
<https://developer.garmin.com/connect-iq/core-topics/sensors/> liefert per HTTP-Fetch nur die Navigation und
ein leeres `<h1 class="c013 c019"></h1>` — die Seite ist clientseitig gerendert. Dasselbe gilt für
`core-topics/activity-recording/`. **Ich konnte den Fließtext dieser beiden Guides also nicht verifizieren**
(siehe "Was nicht auffindbar war"). Die API-Referenz unter `/connect-iq/api-docs/` ist dagegen statisches
HTML und war vollständig lesbar — alle obigen Zitate stammen von dort.

**(c) Kein Garmin-Staff-Statement gefunden.** Details siehe "Was nicht auffindbar war".

**(d) Community-Konsens zur Machbarkeit (nur als Kontext, keine Primärquelle):** In mehreren
Garmin-Forenthreads (Wearables/Health-Bereich, nicht Developer) wird beschrieben, dass die native Zählung
"the same way it counts steps" über den Beschleunigungssensor läuft und in der Praxis fehleranfällig ist,
besonders bei unstrukturierten Workouts. Das stützt die Annahme, dass eine eigene Implementierung für einen
*fest bekannten* Bewegungsablauf (z.B. Kettlebell-Swing im EMOM-Takt) realistisch sein kann — belegt ist es
aber nicht.

### Sicherheit

- "Kein offizielles Garmin-Sample im `garmin/connectiq-apps`-Repo": **verifiziert aus Primärquelle**
  (vollständige Verzeichnisauflistung).
- "Kein Core-Topics-Guide dazu": **nicht abschließend feststellbar**, weil der Sensors-Guide nicht lesbar war.
- "Kein Garmin-Staff-Statement": **konnte ich nicht finden** — Nichtfinden ist kein Beweis für Nichtexistenz.

---

## 4. Liefert die Garmin Activity/Health API nachträglich Rep-/Satz-Daten?

### Direkte Antwort

**Die Original-FIT-Datei ist über die Activity API verfügbar — und die enthält bei nativ aufgezeichnetem
Strength Training die `SET`-Messages mit Wiederholungszahlen.** Praktisch scheitert der Weg für dieses
Projekt aber daran, dass das Garmin Connect Developer Program laut Garmins eigener FAQ ausschließlich für
geschäftliche Nutzung ist. Ob die *JSON*-Antwort der Activity-Details-Endpunkte Reps/Sets als Felder
enthält, konnte ich **nicht** verifizieren (Doku hinter Login).

### Evidenz

**Activity API** — <https://developer.garmin.com/gc-developer-program/activity-api/>:

> "The Activity API provides access to the detailed fitness data captured during an activity on the user's
> wearable device or cycling computer."

> "**Full Activity Details Access:** Activity data files (.FIT, GPX, .TCX formats) available for complete
> activity details"

Die Seite verweist für das FIT-Format explizit auf die FIT-SDK-Doku ("If you are interested in finding out
more about the FIT file, check out the FIT SDK documentation").
→ Wenn man die unveränderte `.FIT`-Datei bekommt, bekommt man auch die `SET`-Messages darin.

> "After approval, you will have access to an evaluation environment to test the Garmin Connect Activity API."

**Zugangsbeschränkung** — <https://developer.garmin.com/gc-developer-program/program-faq/>:

> "The Garmin Connect Developer Program is available for **enterprise use** and is the quickest way to make
> Garmin devices a part of your platform…"

> "There are no licensing or maintenance fees for access to the Garmin Connect Developer Program, but it is
> **only for business use**. Access to some metrics may require a license fee payment or minimum device order
> quantity for commercial use."

> "After you request the Garmin Connect Developer Program, we will confirm the status of your application
> within two business days. […] A typical integration takes between 1 and 4 weeks."

**Health API** — <https://developer.garmin.com/gc-developer-program/health-api/> beschreibt seinen Umfang als:

> "We provide data in JSON format, which summarizes the individual user data uploaded to Garmin Connect from
> supported devices. Data includes heart rate, steps, calories, sleep, respiration, body composition as well
> as detailed stress, pulse-ox, and epoch summaries for all-day activities."

→ Keine Erwähnung von Aktivitätsdetails, Sätzen oder Wiederholungen. Für Aktivitätsdaten ist die **Activity
API** zuständig, nicht die Health API.

### Sicherheit

- ".FIT/GPX/TCX-Dateien sind über die Activity API verfügbar" + "only for business use":
  **verifiziert aus Primärquelle** (wörtliche Zitate von developer.garmin.com).
- "Die FIT-Datei einer nativen Strength-Aktivität enthält `SET`-Messages": **verifiziert für das FIT-Format**
  (Abschnitt 5), **inferiert** für den konkreten Fall Venu 4 — ich habe keine echte Venu-4-Strength-FIT-Datei
  geprüft.
- "Die Activity-Details-**JSON**-Antwort enthält Reps/Sets": **konnte ich nicht feststellen** — die
  Endpunkt-/Feld-Dokumentation liegt hinter dem Developer-Portal-Login.

---

## 5. FIT SDK: Was an Rep-Daten prinzipiell existiert

### Direkte Antwort

Das FIT-Protokoll hat eine dedizierte **`set`-Message (Global Message Number 225)** mit einem Feld
`repetitions`. Sie beschreibt genau das, was das native Strength-Profil produziert — und ist die Message,
die Connect IQ nicht schreiben und nicht lesen kann.

### Evidenz

**Quelle: Garmins eigenes FIT-Python-SDK, generiertes Profil**
<https://github.com/garmin/fit-python-sdk/blob/main/garmin_fit_sdk/profile.py>
(Header: "Copyright 2026 Garmin International, Inc. / Licensed under the Flexible and Interoperable Data
Transfer (FIT) Protocol License")

Message-Number-Tabelle: `225: 'set'`

Felder der `set`-Message (Feldnummer → Name, Typ, Skalierung/Einheit, Original-Kommentar):

| # | Name | Typ | Einheit/Scale | Kommentar im Garmin-Profil |
|---|---|---|---|---|
| 254 | `timestamp` | date_time | — | "Timestamp of the set" |
| 0 | `duration` | uint32 | scale 1000, "s" | — |
| **3** | **`repetitions`** | **uint16** | — | **"# of repitions of the movement"** (Tippfehler im Original) |
| 4 | `weight` | uint16 | scale 16, "kg" | "Amount of weight applied for the set" |
| 5 | `set_type` | set_type (uint8) | — | — |
| 6 | `start_time` | date_time | — | "Start time of the set" |
| 7 | `category` | exercise_category (Array) | — | — |
| 8 | `category_subtype` | Array | — | "Based on the associated category, see [category]_exercise_names" |
| 9 | `weight_display_unit` | — | — | — |
| 10 | `message_index` | — | — | — |
| 11 | `wkt_step_index` | message_index | — | — |

Enum `set_type`: `0: 'rest'`, `1: 'active'`.

Enum `exercise_category` (Auszug, 0–53 + `65534: 'unknown'`): `0 bench_press, 1 calf_raise, 2 cardio,
3 carry, 4 chop, 5 core, 6 crunch, 7 curl, 8 deadlift, 9 flye, 10 hip_raise, 11 hip_stability,
**12 hip_swing**, 13 hyperextension, … 18 olympic_lift, … 24 shoulder_press, … 28 squat, 29 total_body,
… 34 cardio_sensors, … 38 battle_rope, 44 sandbag, 45 sled, 46 sledge_hammer, 49 suspension, 50 tire`.

Der Kommentar bei `34: 'cardio_sensors'` ist aufschlussreich:
> "Exercises within workouts that use GPS/sensors rather than **rep counting**"

→ Garmin unterscheidet im Profil explizit zwischen rep-gezählten und sensor-gemessenen Übungen.

**Direkt relevant für emom_app:** Enum `hip_swing_exercise_name`:
`0: 'single_arm_kettlebell_swing'`, `1: 'single_arm_dumbbell_swing'`, `2: 'step_out_swing'`,
`3: 'one_arm_swing'`.
Das FIT-Format kennt den einarmigen Kettlebell-Swing also als benannte Übung — die Datenstruktur für
"12 Wiederholungen einarmiger Kettlebell-Swing" existiert vollständig. Nur der Schreib-/Lesezugriff aus
Connect IQ heraus fehlt.

**Gegenüberstellung Connect IQ ↔ FIT:**

| | FIT-Format | Connect IQ erreichbar? |
|---|---|---|
| `set` (225), `repetitions`, `weight`, `category` | ja | **nein** — `FitContributor` kennt nur MESG_TYPE 18/19/20 |
| `session` (18) | ja | ja (Developer-Felder) |
| `lap` (19) | ja | ja (`addLap()` + Developer-Felder) |
| `record` (20) | ja | ja (Developer-Felder) |

### Sicherheit

**Verifiziert aus Primärquelle** (Garmins eigenes, generiertes FIT-Profil im offiziellen
`garmin/fit-python-sdk`-Repository). Die Feldnummern und Enums sind wörtlich daraus entnommen.

---

## Praktische Konsequenz für emom_app

Drei Optionen, in absteigender Realisierbarkeit:

1. **Eigene Rep-Erkennung in `garmin_watch_app/`** — `Sensor.registerSensorDataListener()` mit
   `:accelerometer => {:enabled => true, :sampleRate => <getMaxSampleRateForSensorType(:accelerometer)>}`,
   Permission `Sensor` im Manifest, Auswertung selbst geschrieben. Vorteil: die App weiß aus dem
   EMOM-Plan bereits, *welche* Übung gerade läuft (Kettlebell-Swing, Snatch, Mace 360 …) — das ist genau der
   Kontext, den Garmins generischer Algorithmus laut Community-Threads nicht hat und an dem er scheitert.
   Nachteil: kein Garmin-Sample, kein Guide, komplette Eigenentwicklung; nur in einer Watch-App möglich,
   nicht in einem Datenfeld.
2. **Native Aktivität parallel laufen lassen** und die Rep-Zahlen nur in Garmin Connect ansehen. Die
   emom_app bekommt davon nichts mit — es gibt keine Brücke.
3. **Activity API nachträglich** (FIT-Download mit `SET`-Messages) — scheitert an "only for business use".

---

## Was nicht auffindbar war

Explizit ungeklärt geblieben, ohne Ersatz durch Vermutungen:

1. **Der Fließtext der Core-Topics-Guides "Sensors" und "Activity Recording".**
   <https://developer.garmin.com/connect-iq/core-topics/sensors/> und
   <https://developer.garmin.com/connect-iq/core-topics/activity-recording/> liefern per HTTP-Fetch nur
   Navigation und ein leeres `<h1>` — clientseitig gerendert. Falls dort zusätzliche Aussagen zu
   Sample-Raten, Batterieverbrauch oder Strength-Training stehen, habe ich sie **nicht** gesehen.
   Alle Sensor-/Recording-Aussagen oben stammen ausschließlich aus der statischen API-Referenz.

2. **Ein Statement eines Garmin-Mitarbeiters zu genau dieser Frage.**
   Durchsucht: `forums.garmin.com` Developer-Bereich (Connect IQ App Development Discussion, App Ideas, Bug
   Reports, FIT SDK Discussion). Die inhaltlich einschlägigen Threads
   — "Need a better Activity API" (280011), "Changing a Workout datas (reps, load, …) without access to
   HealthSDK" (324081), "Examples for encoding strength training activity files" (FIT-SDK 270009),
   "Getting Accelerometer data" (413675, **0 Antworten**) —
   enthalten **ausschließlich Community-Antworten, keine erkennbar von Garmin-Mitarbeitern**. Ich habe
   deshalb keine einzige Forum-Aussage als Primärquelle gewertet, sondern nur als Korroboration markiert.

3. **Die konkrete maximale Accelerometer-Sample-Rate der Venu 4.**
   Nicht dokumentiert; nur zur Laufzeit per `Sensor.getMaxSampleRateForSensorType(:accelerometer)`
   feststellbar. Die 25 Hz aus Garmins Codebeispiel sind ein Beispielwert, kein Limit.

4. **Ob die Activity-Details-**JSON**-Antwort der Garmin Activity API Reps/Sets als eigene Felder enthält.**
   Die Endpunkt- und Feld-Dokumentation liegt hinter dem Login des Garmin Developer Portals und war ohne
   genehmigten Programmzugang nicht einsehbar. Verifiziert ist nur, dass die **FIT-Datei** bereitgestellt
   wird — und dass diese das `set`-Message-Format grundsätzlich unterstützt.

5. **Ob eine Venu-4-Strength-Aktivität tatsächlich `set`-Messages mit gefülltem `repetitions`-Feld erzeugt.**
   Das FIT-Format sieht es vor, und Garmin Connect zeigt Wiederholungen an — eine echte Venu-4-FIT-Datei
   habe ich aber nicht dekodiert. Formal: **inferiert, nicht verifiziert.**

6. **Der Garmin Health SDK.**
   <https://developer.garmin.com/health-sdk/> lieferte beim Abruf leeren Inhalt. In Forumthread 324081 wird
   ein "HealthSDK" als der Weg genannt, um Workout-Daten direkt zu manipulieren
   (Zitat Nutzer *Ulysse*: "HealthDSK seems to be the obvious choice here, to be able to interact with
   workouts datas directly, but as i'm working on my own and not with a company, I can't have access to
   that."). **Was der Health SDK genau kann und ob er Rep-Daten umfasst, konnte ich nicht verifizieren** —
   die Aussage stammt von einem Community-Nutzer, nicht von Garmin, und die offizielle Seite war nicht
   abrufbar. Der Zusatz "not with a company … can't have access" deckt sich allerdings mit der verifizierten
   FAQ-Aussage "only for business use".

---

## Quellenliste

**Connect IQ API-Referenz (statisches HTML, vollständig verifizierbar)**
- <https://developer.garmin.com/connect-iq/api-docs/class_list.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/Info.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/WorkoutStep.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/WorkoutStepInfo.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording/Session.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityMonitor/Info.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/FitContributor.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/PersistedContent.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor/SensorData.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor/AccelerometerData.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorHistory.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorLogging.html>
- <https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorLogging/SensorLogger.html>

**FIT SDK**
- <https://github.com/garmin/fit-python-sdk/blob/main/garmin_fit_sdk/profile.py> (generiertes FIT-Profil)
- <https://developer.garmin.com/fit/>

**Garmin Connect Developer Program**
- <https://developer.garmin.com/gc-developer-program/activity-api/>
- <https://developer.garmin.com/gc-developer-program/health-api/>
- <https://developer.garmin.com/gc-developer-program/program-faq/>

**Offizielle Samples**
- <https://github.com/garmin/connectiq-apps>

**Foren (nur Korroboration, keine Garmin-Staff-Antworten)**
- <https://forums.garmin.com/developer/connect-iq/f/discussion/280011/need-a-better-activity-api>
- <https://forums.garmin.com/developer/connect-iq/f/discussion/324081/changing-a-workout-datas-reps-load-without-access-to-healthsdk>
- <https://forums.garmin.com/developer/connect-iq/f/discussion/413675/getting-accelerometer-data>
- <https://forums.garmin.com/developer/fit-sdk/f/discussion/270009/examples-for-encoding-strength-training-activity-files>
