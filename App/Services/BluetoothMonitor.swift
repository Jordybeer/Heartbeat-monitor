import CoreBluetooth
import HeartbeatCore

final class BluetoothMonitor: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var onSample: ((HeartRateSample) -> Void)?
    var onStatus: ((String) -> Void)?
    var onDevices: (([SensorDevice]) -> Void)?
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var candidates: [UUID: CBPeripheral] = [:]
    private let service = CBUUID(string: "180D")
    private let characteristic = CBUUID(string: "2A37")
    private var enabled = false
    private var selectedID: UUID? { UserDefaults.standard.string(forKey: "sensorID").flatMap(UUID.init(uuidString:)) }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "beer.jordy.heartbeat.central", CBCentralManagerOptionShowPowerAlertKey: true])
    }
    func start() { enabled = true; search() }
    func stop() {
        enabled = false; central.stopScan()
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil
    }
    func select(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: "sensorID")
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        if enabled { search() }
    }
    func forget() { UserDefaults.standard.removeObject(forKey: "sensorID") }
    private func search() {
        guard enabled else { return }
        guard central.state == .poweredOn else {
            onStatus?(central.state == .unauthorized ? "Bluetooth-toegang ontbreekt. Controleer Instellingen." : "Wachten op Bluetooth…")
            return
        }
        onStatus?("Zoeken naar een hartslagsensor…")
        let connected = central.retrieveConnectedPeripherals(withServices: [service])
        for item in connected { remember(item) }
        if let selectedID, let known = central.retrievePeripherals(withIdentifiers: [selectedID]).first {
            connect(known); return
        }
        if let airpods = connected.first(where: { $0.name?.localizedCaseInsensitiveContains("airpod") == true }) { connect(airpods); return }
        central.scanForPeripherals(withServices: [service], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    private func remember(_ item: CBPeripheral) {
        candidates[item.identifier] = item
        onDevices?(candidates.values.map { SensorDevice(id: $0.identifier, name: $0.name ?? "Hartslagsensor") }.sorted { $0.name < $1.name })
    }
    private func connect(_ item: CBPeripheral) {
        guard enabled else { return }
        peripheral = item; item.delegate = self; central.stopScan()
        onStatus?("Verbinden met \(item.name ?? "sensor")…")
        if item.state == .connected { item.discoverServices([service]) } else { central.connect(item) }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) { search() }
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        for item in dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? [] { remember(item) }
        if enabled { search() }
    }
    func centralManager(_ central: CBCentralManager, didDiscover item: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard enabled else { return }; remember(item)
        if item.identifier == selectedID || (selectedID == nil && item.name?.localizedCaseInsensitiveContains("airpod") == true) { connect(item) }
    }
    func centralManager(_ central: CBCentralManager, didConnect item: CBPeripheral) {
        guard enabled, item.identifier == peripheral?.identifier else { central.cancelPeripheralConnection(item); return }
        item.delegate = self; item.discoverServices([service])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect item: CBPeripheral, error: Error?) {
        guard enabled else { return }; onStatus?("Verbinding mislukt. Tik op Stop en probeer opnieuw.")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral item: CBPeripheral, error: Error?) {
        guard enabled, item.identifier == peripheral?.identifier else { return }
        onStatus?("Verbinding onderbroken; wachten op de sensor…"); central.connect(item)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard enabled, peripheral.identifier == self.peripheral?.identifier else { return }
        guard error == nil, let found = peripheral.services?.first(where: { $0.uuid == service }) else {
            onStatus?("Deze verbinding levert geen openbare hartslagservice. Dagelijkse AirPods-meting is nog niet bevestigd."); return
        }
        peripheral.discoverCharacteristics([characteristic], for: found)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard enabled, peripheral.identifier == self.peripheral?.identifier else { return }
        guard error == nil, let value = service.characteristics?.first(where: { $0.uuid == characteristic }) else { onStatus?("Geen hartslaggegevens beschikbaar van deze sensor."); return }
        peripheral.setNotifyValue(true, for: value)
        onStatus?("Verbonden. Wachten op een echte meting…")
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor value: CBCharacteristic, error: Error?) {
        guard enabled, peripheral.state == .connected, peripheral.identifier == self.peripheral?.identifier, value.uuid == characteristic, error == nil,
              let data = value.value, let packet = HeartRatePacket.decode(data) else { return }
        let now = Date()
        onSample?(.init(bpm: packet.bpm, timestamp: now, receivedAt: now, source: peripheral.name ?? "Bluetooth-sensor"))
    }
}
