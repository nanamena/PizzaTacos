# Workouts — SwiftUI, iOS 26+

## Avvio
1. Apri `WorkoutsDemo.xcodeproj` con Xcode 26 o successivo.
2. Seleziona lo schema WorkoutsDemo e un simulatore iPhone con iOS 26+.
3. Premi Run. Per un iPhone fisico scegli il tuo Team in Signing & Capabilities e un Bundle Identifier univoco.

## Incluso
- Font di sistema San Francisco con stili semantici; nessun font esterno.
- Titolo Workouts e pulsante + allineati, con pulsante Liquid Glass nativo.
- Picker segmentato All/Favorites, menu di ordinamento per data, nome e durata, ordine crescente/decrescente.
- List insetGrouped con NavigationLink, SF Symbols e orologio accanto alla durata.
- Preferiti via dettaglio, swipe o menu contestuale; eliminazione con conferma.
- Form dimostrativo per aggiunta/modifica; nome obbligatorio.
- Salvataggio locale tramite UserDefaults e Codable. La collezione vuota resta vuota al riavvio.
- TabView nativa, modalità chiara/scura, Dynamic Type e descrizioni VoiceOver.
- Nessuna mascotte o dipendenza esterna.

## Integrazione in un progetto esistente
Importa `Workout.swift` e `WorkoutsView.swift`. Mostra `WorkoutsRootView()` dalla tua App. Non importare `WorkoutsApp.swift` se esiste già un tipo `@main`.
Se hai già una TabView usa `WorkoutsView(store:)` nella tua NavigationStack e applica `.tint(WorkoutTheme.accent)`.

Il titolo è un HStack nel contenuto della List, con font largeTitle: consente l'allineamento esatto al + richiesto e scorre con la lista. Non replica il collasso automatico del large title della navigation bar. La tab bar è interamente gestita dal sistema: materiali e misure dipendono dalla versione iOS e dalle impostazioni di accessibilità.

## Confini del prototipo
Questa consegna implementa la schermata della collezione. Progress è una schermata dimostrativa con selezione Week/Month/Year, statistiche, mappa muscolare schematica e costanza settimanale. I dati sono etichettati DEMO e non derivano dalle schede salvate. Non contiene timer, scansione, importazione o storico sessioni. Il form aggiunge riepiloghi dimostrativi, non esercizi completi.
Le durate sono stime di esempio, non calcoli: sostituisci `estimatedMinutes` con il risultato del tuo modello di esercizi, serie, ripetizioni e recuperi. Il numero degli esercizi va analogamente derivato dal modello reale.
UserDefaults è adatto a questa demo piccola; per dati completi usa il tuo archivio o SwiftData. Non è presente sincronizzazione cloud.

## Mascotte
In `WorkoutsView.swift` trovi il commento `Mascot insertion point`. Aggiungi lì una Section con `Image("Mascot").resizable().scaledToFit()` e sfondo riga trasparente, dopo aver inserito l'immagine in Assets. Considerala decorativa con `.accessibilityHidden(true)` e nascondila o riducila con testo molto grande. Non sovrapporla alla tab bar.

## Verifiche manuali in Xcode
- Avvio, apertura dettaglio e ritorno.
- Preferiti, cambio filtro, ordinamento e gestione lista vuota.
- Aggiunta, modifica, annullamento, eliminazione e riavvio.
- Light/Dark, VoiceOver, Dynamic Type accessibilità, Reduce Transparency.
- Le preview incluse usano dati in memoria, senza alterare il salvataggio.

Documentazione Apple: https://developer.apple.com/documentation/swiftui/tabview
https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass
https://developer.apple.com/design/human-interface-guidelines/materials

## Verifica eseguita
Build Debug per iPhone Simulator arm64 riuscita con Xcode 27.2, deployment target iOS 26.0. In questo ambiente il servizio Simulator non è disponibile: verifica visiva e interazioni sul dispositivo da eseguire. Per la verifica in ambiente ristretto è stato disabilitato il sandbox del processo macro Swift, senza modificare il progetto distribuito.

## Revisione — Step 1
Intestazione estratta in WorkoutsHeader: SF standard bold 36 pt con Dynamic Type, + con cerchio 44 pt e Liquid Glass, allineamento verticale centrale. Sfondo rosa tenue con gradiente delicato. Preview isolata “Step 1 — Header only” per verificare questo componente prima di procedere. Build simulator arm64 riuscita; fedeltà visiva non ancora verificata in esecuzione.

## Revisione — Step 2
WorkoutFilterControl: Picker segmentato nativo All/Favorites, controlSize large, stessa larghezza del titolo e distanza di 20 pt. La cornice di layout è almeno 44 pt; non forza lo stretching del segmento nativo. Forma e altezza effettive sono gestite da iOS e possono differire dalla capsula illustrata nel mockup. A dimensioni Dynamic Type di accessibilità usa un Picker menu per evitare testo troncato. Preview interattive “Step 2 — Header and filter” e “Step 2 — Accessible filter”. Build simulator arm64 riuscita; verifica visiva da eseguire sul simulatore.

## Revisione — Step 3
Riga conteggio e ordinamento estratta in WorkoutCollectionControls e spostata nel contenuto superiore: margini allineati a titolo e filtro senza inset automatici degli header List. Font SF body, conteggio primary, menu rosa con frecce e chevron. Distanza dal filtro 28 pt più eventuale spazio intrinseco del controllo; sezione elenco a 12 pt. Conteggio filtrato e plurale corretto, menu nativo con criterio/verso, layout verticale per testo accessibilità. Preview interattiva “Step 3 — Count and sorting”. Build simulator arm64 riuscita; verifica visiva in simulatore ancora da eseguire.

## Revisione — Step 4
Righe con icona SF scura su fondo rosa 48×48 pt, raggio 13 pt; distanza icona/testo 16 pt, titolo SF headline bold e metadati SF 14 pt scalabili. Orologio e cuore rosa, separatori allineati al bordo interno e chevron nativa del NavigationLink. Altezza base circa 66 pt, senza fissare altezza o numero di righe: testo e metadati vanno a capo se necessario. Il contenitore resta List insetGrouped con sfondo semantico opaco. Le icone sono equivalenti SF Symbols, non le illustrazioni personalizzate del mockup. Preview “Step 4 — Workout rows” e “Step 4 — Accessible rows”. Build simulator arm64 riuscita; resa visiva non ancora verificata nel simulatore.

## Revisione — Step 5
TabView nativa con minimizzazione disattivata e tinta rosa adattiva; selezione, vetro e safe area restano gestiti dal sistema. Margini espliciti della lista: 20 pt orizzontali, 0 pt superiore oltre al padding header, 24 pt inferiore. Nessun distanziatore rigido o mascotte. Preview “Step 5 — Full screen” include la tab bar vera con archivio in memoria; usa Settings > Appearance nella preview per verificare Light/Dark. Build simulator arm64 riuscita. Verifica visiva e interazioni nel simulatore non eseguite perché il servizio Simulator non è disponibile in questo ambiente; non si dichiara una corrispondenza pixel-perfect al mockup.
