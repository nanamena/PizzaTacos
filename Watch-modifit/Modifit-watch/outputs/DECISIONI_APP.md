# Modifit Watch — decisioni del progetto

## Obiettivo

App watchOS di fitness con routine guidate, timer per gli esercizi e pause tra una serie e l'altra. La mascotte è un gelato sportivo e accompagna l'utente in ogni fase.

## Struttura delle schermate

1. **Lista Routine**
   - È la prima schermata dell'app.
   - Titolo `Routines` in alto a sinistra.
   - Tre routine visualizzate una sotto l'altra:
     - Full Body — 8 exercises · ~41 min
     - Lower Body — 5 exercises · ~25 min
     - Upper Body — 5 exercises · ~25 min

2. **Schermata Start**
   - Si apre selezionando una routine.
   - Mostra la mascotte del gelato in dimensione 170 × 170.
   - Pulsante giallo `Start`.
   - Pulsante Back con freccia in alto a sinistra: torna alla lista delle routine.

3. **Allenamento**
   - Parte dopo la pressione di `Start`.
   - Timer con conto alla rovescia di 45 secondi, non cronometro.
   - Mascotte sulla cyclette, in dimensione 170 × 120.
   - Pulsanti durante l'esercizio: `Pause` e `Next`.
   - Quando l'utente mette in pausa, i pulsanti diventano `Resume` e `Back`.
   - `Back` durante la pausa torna alla schermata Start della routine.
   - Alla fine dei 45 secondi, oppure premendo `Next`, l'app passa alla pausa.

4. **Pausa**
   - Timer con conto alla rovescia di 12 secondi.
   - Mascotte che riposa sulla panca, in dimensione 170 × 120.
   - Pulsanti `+15 s` e `Next`.
   - `+15 s` estende la pausa di 15 secondi.
   - `Next` torna al prossimo esercizio con timer di 45 secondi.

5. **Overtime della pausa**
   - Se l'utente non preme `Next` prima della fine della pausa, appare la schermata overtime.
   - Mostra il tempo superato in rosso con formato `+0:SS` e il pulsante `Next`.
   - Non viene mostrato un orologio aggiuntivo.
   - All'inizio usa la mascotte sciolta in piedi; dopo 20 secondi passa alla posa sciolta sdraiata.
   - Le mascotte sono centrate e grandi 170 × 170.

## Mascotte e risorse

- Logo dell'app: gelato con manubrio su sfondo azzurro, configurato come App Icon.
- Mascotte iniziale: asset `Mascot`.
- Allenamento: `MascotBikeA` e `MascotBikeB`.
- Pausa: `MascotRestA` e `MascotRestB`.
- Overtime: `MascotOvertimeA` e `MascotOvertimeB`.

## Animazioni

- Le due pose della mascotte cambiano ogni 0,30 secondi.
- Il passaggio tra le pose usa una dissolvenza continua, senza fotogrammi vuoti o spegnimenti dell'immagine.
- La pausa blocca anche l'animazione della mascotte dell'allenamento.
- I cambi tra allenamento, pausa, overtime e schermata Start usano una dissolvenza morbida.
- Il cambio di posa nella schermata overtime mantiene entrambe le immagini disponibili durante la dissolvenza, così non compare un fotogramma nero.

## Organizzazione dei file

- `RoutinesWatch/RoutinesView.swift`: lista delle routine e flusso verso Start/allenamento.
- `Modifit/StartScreenView.swift`: schermata Start con il pulsante Back.
- `Modifit/WorkoutSessionView.swift`: allenamento, timer 45 secondi, Pause/Resume/Back/Next.
- `Modifit/AnimatedMascotView.swift`: animazione riutilizzabile delle coppie di pose della mascotte.
- `RestWatch/RestIntervalView.swift`: pausa con timer 12 secondi, +15 s e Next.
- `RestWatch/RestOvertimeView.swift`: pausa scaduta e cambio della mascotte dopo 20 secondi.
- `Modifit/Assets.xcassets`: logo, mascotte iniziale e mascotte della cyclette.
- `RestWatch/Assets.xcassets`: mascotte della pausa e dell'overtime.

## Stato verificato

Il progetto compila correttamente per il simulatore watchOS.
