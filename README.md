# Heartbeat

Een rustige, native hartslagmonitor voor iPhone 17 en AirPods Pro 3. Vereist **iOS 26 of nieuwer**.

## Wat de app doet

- Live BPM, bron en tijd van de laatste echte meting.
- Groeiende grafiek met selecteerbare meetpunten en zichtbare datagaten.
- Lokale sessiegeschiedenis, overschrijdingslog en delen als CSV met UTC-tijdstempels.
- Instelbare hoge BPM-grens, minimale duur en herstelmarge; meldingen staan eerst uit.
- Live Activity voor toegangsscherm en Dynamic Island, met verouderingsstatus en stopknop.
- Instelbare automatische dagelijkse verbinding en handmatige start/stop.
- Apple Gezondheid: de afgelopen 24 uur apart bekijken en expliciete work-outs registreren.
- Geen account, cloudsync, reclame of analytics.

## Twee meetroutes

**Dagelijks (experimenteel):** de app zoekt de openbare Bluetooth Heart Rate Service (`180D` / `2A37`). Bekende of als AirPods herkenbare sensoren worden verbonden; je kunt zelf een gevonden sensor kiezen. Of AirPods Pro 3 dit buiten een work-out aanbieden, moet op echte hardware worden vastgesteld. Verbonden Bluetooth is geen bewijs van dragen of van een actieve hartslagsensor. Zonder verse meting toont de app een streepje.

**Work-out (HealthKit):** start zelf een echte wandeling, loop- of fietssessie. HealthKit verzamelt beschikbare hartslagdata; Apple kan daarbij ook een Apple Watch of andere gekoppelde hartslagsensor selecteren. Daarom noemt de app deze bron niet zonder bewijs ‘AirPods’. De work-out wordt bij stoppen via Apple's workout builder afgerond en opgeslagen.

De dagelijkse route wordt niet ongemerkt vervangen door een fictieve work-out. Directe Bluetooth-metingen blijven lokaal en worden niet nogmaals in HealthKit geschreven.

## IPA downloaden en sideloaden

1. Open [GitHub Actions](https://github.com/Jordybeer/Heartbeat-monitor/actions/workflows/ios.yml) en kies een **geslaagde** run van de gewenste commit.
2. Download het artifact `Heartbeat-IPA-<runnummer>` en pak de ZIP uit.
3. Open `Heartbeat-sideload.ipa` in SideStore. SideStore moet deze met je eigen Apple-account voor je toestel ondertekenen. De build bevat alleen een ad-hoc-metadatahandtekening om de HealthKit-rechten mee te geven; er is geen ontwikkelaarscertificaat of installatieprofiel ingebouwd.
4. **Behoud de app-extensie** (`HeartbeatWidget.appex`). Verwijderen daarvan verwijdert de Live Activity/Dynamic Island-ondersteuning.
5. Sta de gevraagde Bluetooth- of HealthKit-toegang toe wanneer je de betreffende functie gebruikt. Notificaties vraag je pas aan wanneer je de meldingsschakelaar inschakelt.
6. Controleer na installatie én na vernieuwen dat HealthKit en de widget nog werken. SideStore/provisioning kan rechten veranderen; HealthKit verwijderen uit de signing is geen oplossing voor een werkende HealthKit-app.

Bij een gratis account moet de ondertekening tijdig worden vernieuwd, doorgaans binnen zeven dagen. SideStore gebruikt zelf een van de drie beschikbare appslots. `BUILD.txt`, de verwachte én uit de IPA-handtekening gelezen HealthKit-entitlements en `SHA256.txt` reizen mee met het artifact. Deel geen Apple-wachtwoord, pairingbestand of certificaat in deze publieke repository.

## Gebruiksdetails

- Volg onboarding; de schakelaar automatisch starten is daar en in Instellingen beschikbaar.
- **Stop** onderdrukt automatisch hervatten tot je zelf weer op Start drukt of de autostart bewust opnieuw inschakelt. Een lopende work-out start nooit automatisch.
- Een meetpunt is maximaal 15 seconden actueel. Een meetgat reset een nog lopende alarmduur. Meer dan twee minuten zonder data sluit bij nieuwe ontvangst de vorige lokale sessie af.
- Een melding ontstaat pas bij **meer dan** je gekozen grens en voldoende opeenvolgende verse data. Na een melding moet de hartslag eerst onder de herstelgrens komen. Historische HealthKit-data veroorzaakt geen alarm achteraf.
- Standaardvoorbeelden: 120 BPM / 30 seconden / 5 BPM herstelmarge. Ze zijn aanpasbaar en niet als persoonlijke medische grens ingesteld; meldingen staan aanvankelijk uit.
- Lokale bewaring is standaard 30 dagen; 7, 90 en onbeperkt zijn beschikbaar. Wissen raakt geen Apple Gezondheid-data.
- BPM kan op het toegangsscherm en in nieuwe notificaties verborgen worden.
- Openen na een crash sluit onafgeronde lokale sessies af als onderbroken. Een nog actieve HealthKit-work-out wordt eerst hersteld, zodat Stop ook die sessie kan afronden. Nieuwe metingen beginnen een nieuwe lokale log; ontbrekende data wordt nooit ingevuld.

## Build en controle

De workflow gebruikt een GitHub-hosted macOS-runner, selecteert een beschikbare stabiele Xcode 26-toolchain en noteert de exacte versie. Daarna:

1. `swift test` test BLE-pakketdecodering, alarmduur/herstel, veroudering, dubbelen, tijdsvolgorde, grafiekgaten en CSV.
2. XcodeGen maakt het Xcode-project uit `project.yml`.
3. `xcodebuild` compileert de app en de Live Activity-extensie voor echte iPhones zonder ondertekening.
4. De verpakkingsstap geeft HealthKit-rechten mee aan de re-signer en controleert de handtekening en beide executables in de IPA.
5. Een simulator-UI-test loopt onboarding, monitor, geschiedenis en instellingen door en bewaart echte schermopnamen.

Zelf bouwen op een geschikte Mac:

```sh
brew install xcodegen
swift test
xcodegen generate
xcodebuild -project Heartbeat.xcodeproj -scheme Heartbeat -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
bash scripts/package_ipa.sh build/DerivedData/Build/Products/Release-iphoneos/Heartbeat.app
```

## Wat nog op je iPhone getest moet worden

Dagelijkse AirPods-hartslagtoegang; herverbinden en starten bij daadwerkelijk dragen; langdurig meten met vergrendeld scherm; telefoongesprekken en audiowisselingen; batterijverbruik; behouden rechten na SideStore-signing; alarmvertraging op echte hardware. Een succesvolle build of simulatortest bewijst die punten niet.

Geen garantie van automatische start na handmatig wegvegen of toestelherstart. Een Live Activity is geen onbeperkte achtergrondtimer en kan door iOS worden beëindigd. Meldingen volgen iOS-geluid/Focus-instellingen en zijn geen kritiek noodalarm. De app geeft geen diagnose.

Zie [blueprint](docs/blueprint.md), [autonome ontwerpkeuzes](docs/decisions.md) en [implementatieplan](docs/superpowers/plans/2026-10-19-heartbeat.md).
