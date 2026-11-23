# ModiFiT per iPhone e Apple Watch

Dopo la prima sincronizzazione, l’Apple Watch può eseguire una routine anche con l’iPhone lontano. Il Watch registra in Salute se l’utente ha attivato il salvataggio. La cronologia di ModiFiT si aggiorna quando il riepilogo arriva all’iPhone.

## 1. Configurare e avviare i target

1. Apri `Ios-ModiFiT/Pizza&Tacos.xcodeproj` con Xcode 27.2 e installa i componenti iOS e watchOS da **Settings → Components**.
2. Nel progetto seleziona `Pizza&Tacos` e `ModiFiT Watch`. In **Signing & Capabilities** verifica che entrambi usino lo stesso team e la firma automatica. Il minimo è iOS 26.6 per l’app iPhone e watchOS 11.0 per il companion.
3. Verifica che il bundle Watch sia `com.vincenzo-coppola.ModiFiT.watchkitapp` e che `WKCompanionAppBundleIdentifier` sia `com.vincenzo-coppola.ModiFiT`. Nel target iOS, **Build Phases → Embed Watch Content** deve includere `ModiFiTWatch.app`. L’icona Watch proviene dal PNG già presente in `Watch-modifit`.
4. Abbina iPhone e Apple Watch, abilita la modalità sviluppatore sui due dispositivi e selezionali in Xcode Device Hub. Esegui prima lo schema `Pizza&Tacos` sull’iPhone e poi `ModiFiT Watch` sul Watch.

[Configurare un progetto watchOS](https://developer.apple.com/documentation/watchos-apps/setting-up-a-watchos-project) · [Device Hub](https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac)

## 2. Sincronizzare e usare una routine

1. Crea o importa una routine sull’iPhone e apri ModiFiT sul Watch. `PhoneWorkoutSync` invia il catalogo versionato via `WCSession.transferFile`. Modifiche ed eliminazioni pubblicano un nuovo catalogo, anche quando la libreria diventa vuota.
2. Il delegate Watch sposta il file ricevuto appena arriva. `WatchWorkoutModel` verifica il formato, confronta la revisione e sostituisce la cache locale. I tipi usati da entrambe le app vivono in `Ios-ModiFiT/Shared`.
3. Apri la routine e avvia l’allenamento. SwiftUI mostra esercizio, serie, timer o ripetizioni e lascia confermare l’uscita anticipata. Il modello salva l’avanzamento a ogni transizione. Una modifica del catalogo si applica dalla prossima sessione.
4. Per provare l’uso offline, attendi la prima sincronizzazione, rendi l’iPhone irraggiungibile e ripeti l’allenamento al polso usando la copia locale.

[Trasferimenti con Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity) · [Apple HIG per watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)

## 3. Collegare Salute

1. Prima di provare su dispositivi, verifica l’entitlement HealthKit del target Watch e il valore `workout-processing` in `WKBackgroundModes`. Le descrizioni `NSHealthShareUsageDescription` e `NSHealthUpdateUsageDescription` sono nelle impostazioni del target.
2. Sul Watch seleziona **Connect Apple Health** e autorizza gli allenamenti. La preferenza del Watch determina se le sessioni avviate dal polso vengono salvate in Salute. L’utente può scegliere un tipo di attività o avviare la sessione localmente.
3. `WatchWorkoutHealth` avvia una `HKWorkoutSession` e un `HKLiveWorkoutBuilder`. Al termine, attende lo stato `.stopped`, conclude la raccolta e salva. Usa l’UUID della sessione nei metadati e restituisce l’UUID HealthKit a ModiFiT.
4. Apri il riepilogo sul Watch. I campi **Apple Health** e **iPhone** mostrano l’esito del salvataggio e della consegna. Con l’autorizzazione e i dati disponibili, il riepilogo mostra l’energia attiva calcolata da Salute.

[Autorizzazioni HealthKit](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) · [Sessioni di allenamento watchOS](https://developer.apple.com/documentation/healthkit/running-workout-sessions)

## 4. Verificare lo storico e la consegna

1. Ricollega i dispositivi e apri **Progress** su iPhone. La sessione completata sul Watch dovrebbe comparire una volta. `WorkoutHistoryStore` importa per UUID, scrive un file JSON atomico e conferma la ricezione. Conserva la cronologia precedente importandola dalla chiave `modifit.workoutHistory.v1` al primo caricamento.
2. Se il riferimento HealthKit arriva prima dei dati di Salute, la sessione è già nello storico. Riapri **Progress** o aggiorna la schermata per rileggere le calorie.
3. Ripeti il test con salvataggio disattivato, autorizzazione negata o revocata, iPhone chiuso e interruzione durante il salvataggio. Verifica la presenza di una sola riga per sessione e che un’uscita anticipata confermata scarti l’allenamento.
4. Usa il simulatore per dimensioni del testo, VoiceOver, navigazione e timer. Nella coppia simulata il catalogo passa tramite `updateApplicationContext`, che ha un limite di dimensione. Usa una libreria piccola per la prova. Su iPhone e Watch fisici collauda il trasferimento del catalogo con `transferFile`, l’invio dello storico in background, i sensori, il recupero HealthKit e la verifica in Salute.

[Sincronizzazione dei dati HealthKit](https://developer.apple.com/documentation/healthkit/about-the-healthkit-framework) · [Esecuzione su simulatore e dispositivi](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
