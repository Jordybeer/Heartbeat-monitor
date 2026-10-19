# AirPods-hartslag voor iPhone 17 — projectblueprint

Versie 0.5 · 19 oktober 2026 · Oorspronkelijk ontwerp

Dit document bewaart het ontwerp van vóór de implementatie. Na de opdracht voor een autonome one-shot is de native app uitgewerkt; zie `decisions.md` voor concrete keuzes en de README voor bouw- en installatie-instructies. De hardwareproef blijft open. Dit document belooft geen ononderbroken dagelijkse achtergrondmeting voordat die proef slaagt.

## 1. Doel en vaststaande eisen

Een eenvoudige, moderne native iPhone-app die hartslag van AirPods Pro 3 toont, waarden met tijdstempels bewaart en tijdens een meetsessie op de achtergrond bruikbaar blijft.

| Gevraagde functie | Uitwerking in dit ontwerp |
| --- | --- |
| iPhone 17 en AirPods Pro 3 | Fysieke doelhardware voor validatie; exacte iOS-versie nog vast te leggen |
| Achtergrondmonitoring | Expliciete sessie, controle op verse meetdata, herstel bij onderbreking |
| Automatisch starten | Gebruikersvoorkeur: automatisch bij AirPods-gebruik; instelbaar met toggle en handmatige start beschikbaar |
| Apple Gezondheid | HealthKit-integratie, bronherkomst en voorkomen van dubbele metingen |
| Lock Screen / Dynamic Island | Live Activity met BPM, actualiteit en sessiestatus |
| Instelbare BPM-overschrijding | Aan/uit, grenswaarde, duur, herbewapening en meldingshistoriek |
| Groeiende grafiek en tijdslogging | Nieuwe meetpunten tijdens sessies; geschiedenis met echte tijdstempels |
| Clean, modern, simpel | Rustige native bediening; één primaire actie per scherm |
| Later een IPA | Compileren met GitHub Actions; IPA downloaden en sideloaden |

Het primaire gebruik — dagelijkse activiteiten, sporten of beide — is nog niet bevestigd. Daar hangt de meetroute van af. De eerste meerkeuzevraag hierover leverde geen antwoord op. Dit concept kiest daarom nog geen dagelijkse of sportmodus als productvereiste.

## 2. Haalbaarheid en technische grenzen

**Bevestigd door Apple:** AirPods Pro 3 kunnen hartslag leveren tijdens actieve work-outs in ondersteunde apps; minstens één AirPod moet gedragen en verbonden zijn. Apple beschrijft ook automatische selectie van de betrouwbaarste bron bij gelijktijdig gebruik met Apple Watch. Een via HealthKit ontvangen waarde is daardoor niet vanzelf aantoonbaar uitsluitend een AirPods-meting. [A1]

HealthKit heeft vanaf iOS 26 work-outsessies op iPhone. Apple levert een voorbeeld met live gegevens, Lock Screen-bediening en Live Activities. Dat maakt een echte work-outmodus een onderbouwde route. [A2][A3]

**Nog niet aangetoond voor dit project:** direct en langdurig uitlezen van AirPods-hartslag buiten work-outs via openbare Core Bluetooth-API's. Algemene ondersteuning voor BLE-hartslagmeters bewijst niet dat AirPods hun hartslagservice op deze manier toegankelijk maken. Dit vereist de proef in hoofdstuk 3.

Core Bluetooth ondersteunt verwerking van relevante BLE-gebeurtenissen in de achtergrond en herstel van verbindingsstatus. Dat is geen onbeperkte uitvoer van willekeurige code. In iOS 26 beschrijft Apple bovendien ruimere Bluetooth-mogelijkheden tijdens een vooraf gestarte Live Activity. Ook dat geeft geen garantie dat een specifieke AirPods-service bereikbaar is. [A4][A5]

Een Live Activity is een weergave, geen meetsensor. Apple documenteert voor de standaard Live Activity maximaal acht uur activiteit; een beëindigde kaart kan langer op het toegangsscherm blijven. De app moet dus rekening houden met einde, verwijdering en veroudering van die kaart. [A6]

## 3. Meetroute: drie opties en beslispunt

| Route | Geschikt voor | Voordeel | Beperking / beslissing |
| --- | --- | --- | --- |
| A. HealthKit-work-outsessie | Daadwerkelijk sporten | Officiële route voor live metrics en vergrendeld scherm | Geen stille vertaling van een werkdag naar een fictieve work-out; bronselectie en registratiegedrag testen |
| B. Core Bluetooth | Dagelijkse monitoring, indien hardwareproef slaagt | Mogelijk directe metingen zonder work-outregistratie | Toegankelijkheid van AirPods-hartslagservice en gedrag in de achtergrond onbewezen |
| C. Alleen HealthKit lezen | Geschiedenis en aanvullen van gegevens | Goede integratie met bestaande gezondheidsgegevens | Lezen activeert de AirPods-sensor niet vanzelf; geen basis voor een gegarandeerd live alarm |

**Aanbeveling:** gebruik A voor echte work-outs. Onderzoek B als dagelijks volgen het doel is. Gebruik C als aanvullende geschiedenisroute. De interface ondersteunt een verwisselbare meetbron, zodat een uitkomst van de proef geen herbouw van grafiek, logging en meldingen veroorzaakt.

De eerste implementatiefase wordt een kleine native hardwareproef, geen volledige UI:

1. Exact iPhone-model, iOS-versie, AirPods-model en firmware registreren.
2. Work-outroute testen op meetcadans, vergrendeld scherm en bronherkomst.
3. Via openbare Bluetooth-API's vaststellen of hartslag zonder work-out beschikbaar is.
4. Metingen vergelijken terwijl het scherm uit is, een andere app draait en muziek afspeelt.
5. Eén AirPod uitnemen, beide uitnemen, bereik verliezen en opnieuw verbinden.
6. Gedrag tijdens gesprekken en bij audiowisseling naar een ander apparaat meten.
7. Tijd tussen sensorupdate, app-ontvangst, opslag en notificatie vastleggen.
8. Resultaten met en zonder Live Activity vergelijken, inclusief einde van de kaart.

**Go/no-go:** dagelijkse achtergrondmonitoring wordt pas als ondersteund aangemerkt wanneer B op de doelhardware slaagt. Als B faalt, volgt een expliciete scopebeslissing; de app krijgt niet ongemerkt een andere achtergrondtruc.

## 4. Schermen en visuele richting

Ontwerpvoorstel: SwiftUI, systeemtypografie, veel witruimte, duidelijke cijfers, systeemlicht/donker en één ingetogen accentkleur. Rood markeert een ingestelde overschrijding. Kleur draagt nooit als enige de status over.

| Scherm | Inhoud en gedrag |
| --- | --- |
| Eerste gebruik | Korte uitleg, beschikbare meetroute, benodigde toestemmingen en verbindingstest |
| Nu | Grote BPM-waarde, tijd laatste meting, bron, sessiestatus, groeiende grafiek en start/stop |
| Geschiedenis | Sessies per dag, duur, meetdekking en optioneel min/gemiddelde/max |
| Sessiedetail | Tijdlijn, zoomen/selecteren, gaten, overschrijdingen en exacte tijdstempels |
| Instellingen | Automatisch starten, alarmregel, HealthKit, Lock Screen-privacy, bewaarkeuze en toestemmingshulp |

Voorstel: drie hoofdtabs — Nu, Geschiedenis en Instellingen. Sessiedetail opent vanuit Geschiedenis. Er komt geen afzonderlijk scherm voor elke instelling.

Grote tekst, VoiceOver, voldoende contrast en Reduce Motion horen bij de eerste versie. Bij afwezige data staat er bijvoorbeeld ‘Geen actuele meting’, met de tijd van de laatste ontvangen waarde. Een oude waarde blijft niet als schijnbaar live getal staan.

Appnaam, definitieve accentkleur en branding blijven open; ze blokkeren de architectuur niet.

## 5. Grafiek en tijdslogging

De grafiek toont BPM tegenover tijd; het is geen ECG-golf. Iedere werkelijk ontvangen meting krijgt een meettijd en ontvangstmoment. Als de bron geen eigen meettijd levert, wordt de ontvangstmomentbenadering expliciet in het datamodel vastgelegd.

Ontwerpvoorstellen:

- Livevensters van 5, 15 en 60 minuten, plus de hele sessie.
- Aanraken van de lijn toont BPM en tijd; sessiedetail ondersteunt navigatie door langere perioden.
- Een horizontale lijn toont de ingestelde alarmgrens.
- Gaten blijven leeg; pauzes en verbroken verbindingen krijgen een herkenbare markering.
- Ruwe ontvangen waarden blijven behouden. Visuele aggregatie verandert de alarmbeslissing niet.
- Lange overzichten gebruiken tijdvakken met min/max/gemiddelde zodat korte pieken niet verdwijnen.
- Eenheden zijn BPM. Opslag gebruikt absolute tijd; presentatie gebruikt lokale tijd en houdt rekening met tijdzone- en zomertijdwisselingen.

Meetfrequentie volgt wat de sensor/API werkelijk levert. ‘Iedere seconde meten’ en precieze apparaataccupercentages worden geen beloofde functies zolang openbare API's die niet bevestigen.

## 6. Meldingsregel

De gebruiker bepaalt de BPM-grens. De app moet daarnaast weten of een enkele overschrijding volstaat of dat die een ingestelde tijd moet aanhouden. Er wordt geen medische grens uit leeftijd, profiel of geschiedenis afgeleid.

Voorgesteld model: uit → gereed → overschrijding wordt gevolgd → melding aangevraagd → wacht op herstel. Parameters zijn grens, minimale duur, maximale toegestane datakloof, herbewapeningsmarge en eventuele herhaalpauze. De getallen hiervoor zijn nog geen vastgestelde standaardwaarden.

Gedrag:

1. Alleen actuele, bruikbare metingen tellen mee.
2. De gekozen voorwaarde moet door voldoende opeenvolgende ontvangen metingen worden ondersteund; tussen meetpunten wordt geen fysiologische continuïteit verzonnen.
3. Bij een te grote datakloof vervalt de lopende duurvoorwaarde.
4. Eén gebeurtenis geeft één melding, tenzij de gebruiker expliciet herinneringen wil.
5. De regel wordt pas opnieuw gereed na het afgesproken herstelgedrag.
6. Vertraagde historische import veroorzaakt geen alarm alsof de meting net plaatsvond.
7. Het wijzigen van de regel start de beoordeling opnieuw en logt de nieuwe regelversie.

Lokale notificaties houden de eerste versie onafhankelijk van een server. Time Sensitive kan als bewuste keuze worden aangeboden, afhankelijk van systeeminstellingen. Kritieke meldingen die stil/Focus omzeilen vereisen een aparte Apple-toestemming en zijn geen beloofde basisfunctie. [A7][A8]

Een geregistreerde overschrijding, een bij iOS aangevraagde notificatie en een geopende notificatie zijn verschillende gebeurtenissen. De app beweert niet dat de gebruiker de melding heeft gezien of gehoord.

## 7. Lock Screen en Dynamic Island

Dezelfde sessie voedt alle weergaven:

| Weergave | Voorgestelde inhoud |
| --- | --- |
| Dynamic Island compact | BPM of teken voor ontbrekende actuele data, met klein statussymbool |
| Dynamic Island minimaal | Bondige meet-/onderbrekingsstatus |
| Dynamic Island uitgebreid | BPM, actualiteit, sessieduur, kleine trend en stopactie |
| Lock Screen | BPM, bronstatus, duur, compacte trend en openen/stoppen |

Een stopactie is bewust te bedienen. Een tik op de kaart opent de actieve sessie. Verberg op verzoek de BPM op het toegangsscherm en toon alleen dat een sessie actief is.

Updates worden gegroepeerd volgens beschikbare uitvoeringstijd en systeemgedrag. De grafiek binnen de app kan vloeiender bijwerken dan de Live Activity. Voor die kaart wordt geen verversing per seconde beloofd.

Bij het aanmaken krijgt de kaart een verouderingsmoment, zodat de systeemweergave ook zonder verdere app-uitvoering niet onbeperkt actualiteit suggereert. Verouderingsmomenten worden bij verse data herzien. Verwijdering van de kaart mag niet zonder meer een meetsessie stoppen. Omgekeerd moet stoppen de kaart correct beëindigen. Het effect van beëindiging op Bluetooth-privileges wordt in de hardwareproef meegenomen.

## 8. HealthKit-integratie

Minimale toestemmingen worden per gekozen route aangevraagd: hartslag lezen, en alleen waar nodig hartslag schrijven en work-outs lezen/schrijven. Onverwante gezondheidsdata is niet nodig. [A9]

Voor de work-outroute beheert de builder de work-out. Metingen die het systeem al heeft opgeslagen worden niet nogmaals gekopieerd als nieuwe metingen. Voor een eventuele directe Bluetooth-route wordt vóór schrijven onderzocht of iOS dezelfde samples al bewaart. Export blijft uit tot die duplicatieproef slaagt.

De lokale database bewaart sessie-indeling en alarmgebeurtenissen. HealthKit beheert zijn eigen samples. HealthKit-import gebruikt stabiele sample-identiteit en een opgeslagen querypositie; herhalen van import mag geen dubbele lokale records opleveren. Bij wijziging of verwijdering worden afgeleide overzichten opnieuw berekend.

Een lege HealthKit-uitkomst betekent niet aantoonbaar ‘leestoestemming geweigerd’: Apple verbergt die keuze voor de app. De UI gebruikt neutrale uitleg en verwijst naar toegangsinstellingen. Ook toegang bij vergrendeld scherm is een te testen situatie, geen vanzelfsprekendheid. [A2][A9]

Open productkeuze: alleen eigen sessies tonen of ook bestaande HealthKit-hartslaggeschiedenis. Dat beïnvloedt de geschiedenisfilters, niet de live meetkern.

## 9. Architectuur en verantwoordelijkheden

Voorgestelde native stack: Swift, SwiftUI, Swift Charts, HealthKit, ActivityKit/WidgetKit, UserNotifications en waar bewezen Core Bluetooth. Voor lokale opslag: Core Data met SQLite-store, versiebeheer en achtergrondschrijver. Geen externe UI- of databasebibliotheek is hiervoor noodzakelijk.

| Module | Verantwoordelijkheid |
| --- | --- |
| HeartRateProvider | Genormaliseerde metingen en bron-/verbindingsgebeurtenissen leveren |
| WorkoutProvider | De officiële work-outsessie en bijbehorende callbacks beheren |
| BluetoothProvider | Alleen na succesvolle proef: directe AirPods-data en verbindingsherstel |
| SessionCoordinator | Start/stop, route, pauzes en lifecycle beheren |
| MeasurementPipeline | Tijden normaliseren, duplicaten herkennen, actualiteit vaststellen |
| AlertEngine | De alarmregel deterministisch beoordelen, zonder UI-afhankelijkheid |
| Repository | Metingen, sessies, gebeurtenissen en geaggregeerde tijdvakken bewaren |
| HealthKitBridge | Toestemming, geschiedenis en gecontroleerd schrijven/importeren |
| LiveActivityController | Compacte sessiesnapshots publiceren en kaarten beëindigen |
| NotificationService | Meldingen bij iOS aanvragen en gebruikersacties verwerken |
| Presentation | Schermen en grafieken op basis van dezelfde sessiestatus |

De provider levert events aan de pipeline. Die actualiseert de sessiestatus en de alarmbeoordeling, en schrijft gegevens weg. UI en Live Activity gebruiken afgeleide snapshots; zij beheren de sensor niet. Een mockprovider kan dezelfde keten met testdata voeden, maar testdata komt nooit in de echte HealthKit-store.

Een serialiseerde verwerking voorkomt races tussen sample, stoppen en herstel. Het hoofdscherm verwerkt geen databasewerk. Meetverwerking, opslag en kaartupdates krijgen afzonderlijke foutafhandeling zodat een falende kaart niet ook logging beëindigt.

## 10. Datamodel

| Entiteit | Kernvelden |
| --- | --- |
| Session | ID, start/einde, route, startaanleiding (handmatig/automatisch/herstel), gebruikerslabel, status, stopreden, datamodelversie |
| Measurement | ID, sessie-ID, BPM, meettijd, ontvangstmoment, herkomst meettijd, bron-ID, extern sample-ID, ingestieroute |
| Gap | Start/einde, reden voor zover bekend, laatste ontvangen sample |
| ThresholdRule | ID/versie, grens, duur, klooflimiet, herbewapening, herhaalbeleid, aan/uit |
| ThresholdEvent | Regelversie, begin/einde, piek, onderbouwende samples, notificatieverzoek-ID/status |
| SessionEvent | Tijd, gebeurtenistype, bronwissel/onderbreking/regelwijziging/herstel |
| Aggregate | Sessiereferentie, tijdvak, aantal, min/max/gemiddelde, meetdekking |
| Settings | Automatische-startvoorkeur, privacyweergave, HealthKit-keuze, bewaarbeleid, weergavevoorkeuren |

‘Meetdekking’ betekent beschikbaarheid van data, geen klinische nauwkeurigheid. Sensorbetrouwbaarheid of contactkwaliteit wordt alleen opgeslagen als de openbare API die daadwerkelijk levert. Er wordt geen neppercentage voor nauwkeurigheid berekend.

## 11. Onderbrekingen, opslag en privacy

Sessiestatussen: inactief, voorbereiden, wachten op data, meten, onderbroken, stoppen, afgerond en fout. Een vrijwillige pauzeknop blijft een productkeuze; een onderbreking wordt altijd ondersteund.

**Automatische start — gebruikersvoorkeur bevestigd:** de app moet bij voorkeur vanzelf beginnen bij AirPods-gebruik, met een instelling ‘Automatisch starten bij AirPods-gebruik’. Handmatig starten en stoppen blijven beschikbaar. De onboarding maakt duidelijk wanneer de automatische werking actief is en welke toestemmingen ontbreken.

De voorkeur is een instelling; zij is geen bewijs dat iOS de app in iedere toestand kan starten. De hardwareproef moet een openbare, werkende trigger aantonen. Alleen Bluetooth-verbinding is geen bewijs dat een AirPod gedragen wordt of de sensor metingen levert. De interface toont pas ‘Meten’ wanneer actuele metingen werkelijk binnenkomen. Gebeurtenissen voor verbinding, eerste meetdata en daadwerkelijk sessiebegin worden afzonderlijk geregistreerd.

Autostart wordt afzonderlijk getest wanneer de app geopend, op de achtergrond, door het systeem beëindigd, handmatig weggeveegd of na een toestelherstart is. Er wordt geen automatische koude start of draagdetectie beloofd voordat dat op de doelhardware is bevestigd. Als een toestand handmatige hervatting vraagt, krijgt de gebruiker daar duidelijke uitleg over.

Voorgestelde bedieningsregels: uitschakelen van de toggle voorkomt toekomstige automatische starts; een lopende sessie heeft een aparte stopactie. Handmatig stoppen mag niet door hetzelfde aansluit-/draagmoment direct worden ongedaan gemaakt. Herhaalde verbindingscallbacks en herstel maken geen dubbele sessies. Deze regels worden in de sessiecoördinator centraal bewaakt.

Bij geen data: laatste ontvangsttijd tonen, tijdlijn onderbreken en geen BPM-alarm beoordelen op een oude waarde. Bij herstel: echte nieuwe samples opnemen en de duurvoorwaarde opnieuw opbouwen. Bij een andere geselecteerde bron wordt die wissel zichtbaar gelogd; overstappen op Apple Watch gebeurt niet onopgemerkt.

Na een crash wordt beschikbare systeemstatus hersteld waar de gekozen route dat ondersteunt. Crash, expliciet wegvegen en herstart zijn aparte tests. Er is geen belofte van automatisch hervatten na een handmatige force-quit. Gemiste data wordt niet gereconstrueerd als de bron die niet werkelijk heeft bewaard.

Ontwerpvoorstel: verwerking op het apparaat, geen account, advertenties of externe analyse. Lokale bestanden krijgen iOS Data Protection. Het gekozen beschermingsniveau moet schrijven tijdens vergrendeling na eerste ontgrendeling toestaan; vóór eerste ontgrendeling na een reboot wordt geen toegang verondersteld.

Grote grafiekcache hoeft niet gedeeld te worden met de widget; alleen de minimaal nodige sessiesnapshot. Debuglogs bevatten geen ruwe hartslagreeksen. Cloudsync, export en bewaartermijnen zijn expliciete keuzes. Verwijderen in de app en verwijderen uit HealthKit krijgen afzonderlijke, duidelijke acties; data van andere bronnen wordt niet aangeraakt.

## 12. Build, ondertekening en oplevering

Een IPA is een verpakte iOS-app. Voor installatie zijn een passende ondertekening en provisioning nodig; HealthKit, appgroepen en de widgettarget moeten in de werkelijke getekende build correct blijven werken. Beschikbare capabilities hangen mede van het ontwikkelaarsaccount af. [A10]

Deze huidige werkomgeving is Linux. Hier kan het ontwerp en later de broncode worden voorbereid; compileren en archiveren met Apple's iOS-SDK vraagt een Mac of macOS-buildrunner met geschikte Xcode-versie. Een installeerbare IPA wordt pas als geleverd beschouwd na installatie op het doeltoestel.

**Door de gebruiker bevestigd:** compileren via GitHub Actions, installatie van de IPA via sideloading en gebruik van een gratis Apple-account. SideStore is de voorgestelde sideloadmethode, aansluitend op eerder gebruik. Een eigen Mac is daarmee geen noodzakelijke buildomgeving. De doelrepository is [Jordybeer/Heartbeat-monitor](https://github.com/Jordybeer/Heartbeat-monitor), op 19 oktober 2026 bevestigd via de GitHub-integratie: publieke repository met standaardbranch `main` en schrijftoegang. Op dit moment is er nog geen appcode of workflow toegevoegd.

Apple vermeldt de gewone HealthKit-capability en appgroepen ook voor de kosteloze categorie Apple Developer. Dit is op 19 oktober 2026 gecontroleerd in de oorspronkelijke HTML-tabel: beide rijen bevatten een bevestigend pictogram in alle drie de accountkolommen. De afzonderlijke capability HealthKit Estimate Recalibration is hiervoor niet nodig. Een betaald lidmaatschap is dus geen vooronderstelde eis voor gewone HealthKit-toegang. De daadwerkelijke door SideStore gemaakte provisioning en ondertekening blijven apart te valideren. [A10]

Voor de gratis route wordt de IPA in CI gebouwd voor ondertekening door SideStore op het toestel. SideStore beschrijft voor gratis accounts een geldigheid van zeven dagen, periodiek vernieuwen en maximaal drie actieve apps inclusief SideStore. De Live Activity-extensie moet bij installatie behouden blijven. Vernieuwen, bijwerken met behoud van logging en behoud van rechten zijn onderdeel van de installatietest. [A12]

Voorgestelde CI-opzet:

1. Een vastgelegde GitHub-hosted macOS-runner en expliciet gekozen Xcode-versie gebruiken, passend bij de doel-iOS-versie.
2. Bij pull requests compileren en relevante tests uitvoeren zonder ondertekengeheimen.
3. Via een handmatig gestarte build van een gekozen commit de iPhone-app en Live Activity-extensie voor echte apparaten bouwen.
4. Een IPA met beide targets als downloadbaar workflow-artifact publiceren, samen met commit-ID, buildnummer en testresultaten.
5. Op het doeltoestel sideloaden en daarna HealthKit, de widget en achtergrondmeting opnieuw valideren.

Er zijn twee ondertekenroutes. Bij lokaal ondertekenen/herondertekenen levert CI een daarvoor bestemde unsigned IPA; die is vóór geldige ondertekening niet rechtstreeks installeerbaar. Als de gekozen sideloadtool benodigde entitlements verwijdert of niet kan provisionen, geldt deze route niet als geslaagd. Bij ondertekenen in CI worden passende certificaten en provisioningprofielen per target via GitHub Secrets in een tijdelijke keychain geladen. GitHub documenteert deze tweede route officieel. [A11]

App en extensie houden consistente bundle-ID's en eventuele appgroeprechten. Een ondertekende build wordt gecontroleerd op de vereiste entitlements. Geen Apple-wachtwoord of certificaat wordt in een chat of in de repository opgeslagen. De uitgangsroute is gratis ondertekenen met SideStore; ondertekenen in CI blijft alleen een latere alternatieve route als passende certificaten en profielen beschikbaar zijn. Er is nog geen workflow uitgevoerd en nog geen IPA gecompileerd.

Latere oplevering omvat broncode, projectconfiguratie, ondertekeninstructies zonder geheimen, testresultaten, buildversie en de afgesproken installatievorm. Certificaten en privésleutels horen niet in de broncoderepository.

## 13. Test- en acceptatieplan

| Gebied | Vereiste bewijsvoering vóór oplevering |
| --- | --- |
| Meting | Echte BPM op iPhone 17 met AirPods Pro 3, bron duidelijk en meetcadans geregistreerd |
| Achtergrond | Geplande gebruiksduur met scherm uit en andere apps; fouten en meetgaten kwantificeren |
| Dagelijks gebruik | Zonder work-out aantoonbaar werkend voordat die functie als ondersteund geldt |
| Meldingen | Grens, duur, onderbreking, herstel, regelwijziging en dubbele callbacks geven het afgesproken resultaat |
| Vertraging | Sensor-/ontvangsttijd, regelbeslissing en notificatieverzoek afzonderlijk meten |
| Live Activity | Compact, uitgebreid, vergrendeld, verouderd, verwijderd en beëindigd controleren |
| HealthKit | Toegang toestaan/intrekken, lege data, vergrendeling en nul dubbele samples aantonen |
| Logging | Exacte ontvangen waarden terugvinden na afsluiten/herstart; gaten en bronwissels behouden |
| Hardware | Eén/twee AirPods, uitnemen, bereikverlies, lege accu, muziek en telefoongesprek |
| Lifecycle | Crash, force-quit, reboot, energiebesparing en einde Live Activity apart testen |
| Automatische start | Toggle aan/uit, aantoonbare trigger, eerste verse meting, handmatig stoppen en geen dubbele sessies; resultaat per app-/toesteltoestand documenteren |
| Toegankelijkheid | Grote tekst, VoiceOver, contrast en Reduce Motion controleren |
| Installatie | De uiteindelijke getekende app installeren en HealthKit plus widget opnieuw verifiëren |

Unit-tests richten zich op de echte risico's: alarmstatusmachine, tijdsvolgorde, duplicaten en ontbrekende data. Integratietests gebruiken HealthKit-testdata in een geschikte testomgeving. Achtergrondgedrag, batterij en AirPods worden op fysieke hardware beoordeeld; een simulator bewijst die onderdelen niet.

Nog af te spreken numerieke acceptatiecriteria: gewenste sessieduur, maximaal aanvaardbare vertraging, datakloof en batterijverbruik. De app wordt niet op subjectief ‘lijkt live genoeg’ geaccepteerd.

## 14. Bouwvolgorde

1. Gebruiksdoel, hardware en installatiekeuze bevestigen; meetproef en acceptatiecriteria vastleggen.
2. Hardwareproef uitvoeren en de ondersteunde meetroute vastzetten.
3. Meetpipeline, opslag en alarmengine met onderbrekingen bouwen.
4. Nu, Geschiedenis en Sessiedetail op dezelfde gegevensbron aansluiten.
5. HealthKit-integratie, dubbele-samplecontrole en toestemmingservaring afronden.
6. Live Activity, Dynamic Island, lokale meldingen en privacybediening toevoegen.
7. Werkelijke gebruiksduur testen, batterij meten en de getekende installatie opleveren.

Per fase wordt de interface tussen modules behouden. Een eerder ontdekte platformbeperking moet het beslisregister aanpassen, niet laat in het traject het product stilzwijgend versimpelen.

## 15. Beslisregister

| Beslissing | Status | Waarom relevant |
| --- | --- | --- |
| Dagelijks, sporten of beide | Onbeantwoord | Bepaalt de primaire meetroute |
| Exacte iOS-versie, AirPods en eventuele Watch | Onbeantwoord | Compatibiliteit, firmwaregedrag en bronselectie |
| Buildomgeving en distributievorm | Bevestigd: GitHub Actions en IPA via sideloading | macOS-runner; geen TestFlight als gekozen distributieroute |
| Repository | Bevestigd: Jordybeer/Heartbeat-monitor | Publiek; standaardbranch main; schrijftoegang bevestigd |
| Ontwikkelaarsaccount | Bevestigd: gratis Apple-account | Geen actief betaald lidmaatschap aangenomen; geen betalingsgegevens in projectdocumentatie |
| Sideloadtool | Voorgesteld: SideStore, aansluitend op eerder gebruik | Ondertekening, behoud extensie en HealthKit-provisioning op toestel valideren |
| Alleen persoonlijk gebruik of ook verspreiden | Onbeantwoord | Distributie en productondersteuning |
| Sessiestart | Bevestigd: voorkeur automatisch, instelbaar met toggle | Handmatige start blijft beschikbaar; trigger en iOS-toestanden moeten op hardware worden bewezen |
| Gewenste maximale sessieduur | Onbeantwoord | Achtergrond-, batterij- en Live Activity-gedrag |
| Grens, duur, herstel en herinneringen | Onbeantwoord | Correct en voorspelbaar meldingsgedrag |
| HealthKit alleen lezen of ook schrijven | Onbeantwoord | Toestemming en voorkomen van dubbelen |
| Eigen sessies of bredere geschiedenis | Onbeantwoord | Geschiedenisomvang en bronfilters |
| Bewaren, export en cloudsync | Onbeantwoord | Gegevenslevenscyclus |
| Native stack en drie tabs | Ontwerpvoorstel | Eenvoudige uitvoering met passende systeemintegratie |

De build- en accountkeuzes en de voorkeur voor instelbare automatische start zijn vastgelegd. De technische haalbaarheid van automatisch starten blijft onderdeel van de hardwareproef. Het gewenste gedrag bij een overschrijding en de overige onbeantwoorde productkeuzes blijven zichtbaar open. Geen onbeantwoorde keuze geldt als goedgekeurde standaard.

## Bronnen

Gecontroleerd op 19 oktober 2026. Apple-documentatie bevestigt platformmogelijkheden; ontwerpvoorstellen en nog uit te voeren hardwaretests zijn daarvan onderscheiden.

- [A1 — Apple: Je hartslag controleren met AirPods Pro 3](https://support.apple.com/nl-be/123184)
- [A2 — Apple WWDC25: Track workouts with HealthKit on iOS and iPadOS](https://developer.apple.com/videos/play/wwdc2025/322/)
- [A3 — Apple: Building a workout app for iPhone and iPad](https://developer.apple.com/documentation/healthkit/building-a-workout-app-for-iphone-and-ipad)
- [A4 — Apple: Core Bluetooth Background Processing](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)
- [A5 — Apple: Core Bluetooth](https://developer.apple.com/documentation/corebluetooth)
- [A6 — Apple: Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [A7 — Apple: Time Sensitive notifications](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive)
- [A8 — Apple: Critical alerts entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts)
- [A9 — Apple: Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [A10 — Apple: Supported capabilities for iOS](https://developer.apple.com/help/account/reference/supported-capabilities-ios)
- [A11 — GitHub: Installing an Apple certificate on macOS runners for Xcode development](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [A12 — SideStore: Frequently Asked Questions](https://docs.sidestore.io/docs/faq)

Geschatte feitelijke zekerheid van deze conceptblueprint: 90% — subjectieve inschatting, geen gemeten kans. De dagelijkse meetroute, exacte achtergrondcadans en getekende installatie zijn nog niet op doelhardware gevalideerd.
