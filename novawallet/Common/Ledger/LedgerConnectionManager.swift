import Foundation
import CoreBluetooth

enum LedgerDiscoveryError: Error {
    case unknown
    case unauthorized
    case unsupported
    case unavailable
}

typealias LedgerResponseClosure = (Result<Data, Error>) -> Void

protocol LedgerConnectionManagerProtocol: AnyObject {
    var delegate: LedgerConnectionManagerDelegate? { get set }

    func start()
    func stop()
    func send(message: Data, deviceId: UUID, completion: LedgerResponseClosure?) throws
    func cancelRequest(for deviceId: UUID)
}

extension LedgerConnectionManagerProtocol {
    func send(message: Data, deviceId: UUID) throws {
        try send(message: message, deviceId: deviceId, completion: nil)
    }
}

protocol LedgerConnectionManagerDelegate: AnyObject {
    func ledgerConnection(manager: LedgerConnectionManagerProtocol, didReceive error: LedgerDiscoveryError)
    func ledgerConnection(manager: LedgerConnectionManagerProtocol, didDiscover device: LedgerDeviceProtocol)
}

final class LedgerConnectionManager: NSObject {
    weak var delegate: LedgerConnectionManagerDelegate?

    let logger: LoggerProtocol

    private let delegateQueue = DispatchQueue(label: "com.nova.wallet.ledger.connection." + UUID().uuidString)
    private let supportedDevices: [CBUUID: SupportedBluetoothDevice] = SupportedBluetoothDevice.ledgers

    private var centralManager: CBCentralManager?

    @Atomic(defaultValue: [])
    private var devices: [BluetoothLedgerDevice]

    private var supportedDeviceUUIDs: [CBUUID] { supportedDevices.values.map(\.uuid) }
    private var supportedDeviceNotifyUuids: [CBUUID] { supportedDevices.values.map(\.notifyUuid) }

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    private func removeDevices(peripheral: CBPeripheral) {
        devices.removeAll { $0.peripheral == peripheral }
    }

    private func bluetoothDevice(id: UUID) -> BluetoothLedgerDevice? {
        devices.first { $0.identifier == id }
    }

    private func completeRequest(with result: Result<Data, Error>, device: BluetoothLedgerDevice) {
        device.responseCompletion?(result)
        device.responseCompletion = nil
        device.transport.reset()
    }

    private func didDiscoverDevice(_ peripheral: CBPeripheral, advertisementData: [String: Any]) {
        if bluetoothDevice(id: peripheral.identifier) == nil {
            // if peripheral is not connected but discovered
            // the service id is unavailble and extracted from the advertisement list
            let advertisedServiceIds = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
            let connectedServiceIds = peripheral.services?.compactMap(\.uuid) ?? []
            let allServiceIds = connectedServiceIds + (advertisedServiceIds ?? [])

            let deviceModel: LedgerDeviceModel = allServiceIds.compactMap {
                supportedDevices[$0]?.model
            }.first ?? .unknown

            let device = BluetoothLedgerDevice(
                peripheral: peripheral,
                model: deviceModel
            )

            devices.append(device)
            delegate?.ledgerConnection(manager: self, didDiscover: device)
        }
    }
}

extension LedgerConnectionManager: LedgerConnectionManagerProtocol {
    func start() {
        guard centralManager == nil else {
            return
        }

        devices = []
        centralManager = CBCentralManager(
            delegate: self,
            queue: delegateQueue,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false,
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    func stop() {
        centralManager?.delegate = nil
        centralManager?.stopScan()
        centralManager = nil
    }

    func send(message: Data, deviceId: UUID, completion: LedgerResponseClosure?) throws {
        guard let centralManager = centralManager, let device = bluetoothDevice(id: deviceId) else {
            throw LedgerError.deviceNotFound
        }

        centralManager.connect(device.peripheral, options: nil)
        device.writeCommand = { [weak device, weak self] in
            if let currentDevice = device, let characteristic = currentDevice.writeCharacteristic {
                currentDevice.responseCompletion = completion

                // Force iOS to return negotiated mtu instead of the internal buffer size
                let mtu = currentDevice.peripheral.maximumWriteValueLength(for: .withoutResponse)

                let chunks = currentDevice.transport.prepareRequest(from: message, using: mtu)

                self?.logger.debug("Writing \(chunks.count) chunks of data \(message.count) using mtu \(mtu)")

                let type: CBCharacteristicWriteType = completion != nil ? .withResponse : .withoutResponse

                chunks.forEach { currentDevice.peripheral.writeValue($0, for: characteristic, type: type) }
            }
        }
    }

    func cancelRequest(for deviceId: UUID) {
        guard let centralManager = centralManager, let device = bluetoothDevice(id: deviceId) else {
            return
        }

        delegateQueue.async {
            device.responseCompletion = nil

            centralManager.cancelPeripheralConnection(device.peripheral)
        }
    }
}

extension LedgerConnectionManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.debug("Did receive state: \(central.state.rawValue)")

        switch central.state {
        case .poweredOn:
            centralManager?.retrieveConnectedPeripherals(withServices: supportedDeviceUUIDs).forEach { peripheral in
                didDiscoverDevice(peripheral, advertisementData: [:])
            }
            centralManager?.scanForPeripherals(withServices: supportedDeviceUUIDs)
        case .unauthorized:
            delegate?.ledgerConnection(manager: self, didReceive: LedgerDiscoveryError.unauthorized)
        case .poweredOff:
            delegate?.ledgerConnection(manager: self, didReceive: LedgerDiscoveryError.unavailable)
        case .unsupported:
            delegate?.ledgerConnection(manager: self, didReceive: LedgerDiscoveryError.unsupported)
        default:
            delegate?.ledgerConnection(manager: self, didReceive: LedgerDiscoveryError.unknown)
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi _: NSNumber
    ) {
        logger.debug("Did discover device: \(peripheral)")

        didDiscoverDevice(peripheral, advertisementData: advertisementData)
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.debug("Did connect to device: \(peripheral)")

        peripheral.delegate = self
        peripheral.discoverServices(supportedDeviceUUIDs)
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error _: Error?) {
        logger.debug("Device disconnected: \(peripheral)")

        guard let device = bluetoothDevice(id: peripheral.identifier) else { return }

        completeRequest(with: .failure(LedgerError.deviceDisconnected), device: device)
    }

    func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.debug("Did fail to connect \(peripheral): \(String(describing: error))")

        guard let device = bluetoothDevice(id: peripheral.identifier) else { return }

        completeRequest(with: .failure(LedgerError.deviceDisconnected), device: device)
    }
}

extension LedgerConnectionManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        logger.debug("\(peripheral) did discover services with error: \(String(describing: error))")

        guard let services = peripheral.services else { return }

        for service in services { peripheral.discoverCharacteristics(nil, for: service) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        logger.debug(
            "\(peripheral) did discover characteristics for \(service) with error: \(String(describing: error))"
        )

        guard let device = bluetoothDevice(id: peripheral.identifier) else {
            logger.warning("Characteristic discovered for missing device")
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
                device.readCharacteristic = characteristic
            }

            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
                device.notifyCharacteristic = characteristic
            }

            if characteristic.properties.contains(.write) {
                peripheral.setNotifyValue(true, for: characteristic)
                device.writeCharacteristic = characteristic

                if let writeCommand = device.writeCommand {
                    writeCommand()
                    device.writeCommand = nil

                    logger.debug("Did write value for characteristic \(characteristic)")
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        logger.debug("\(peripheral) did write value for \(characteristic) with error: \(String(describing: error))")
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        logger.debug("\(peripheral) did update state for \(characteristic) with error: \(String(describing: error))")

        if let error = error {
            logger.error("Failed to update notification state \(error)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        logger.debug("\(peripheral) did update value for \(characteristic) with error: \(String(describing: error))")

        guard let device = bluetoothDevice(id: peripheral.identifier) else {
            logger.warning("Did receive update for value but device not found")
            return
        }

        if supportedDeviceNotifyUuids.contains(characteristic.uuid) {
            if let error = error {
                logger.error("Failed to update value for \(characteristic): \(error)")
            }

            if let message = characteristic.value {
                do {
                    if let response = try device.transport.receive(partialResponseData: message) {
                        logger.debug("Received response")
                        completeRequest(with: .success(response), device: device)
                    }
                } catch {
                    logger.debug("Can't handle response")

                    device.transport.reset()
                    completeRequest(with: .failure(LedgerError.internalTransport(error: error)), device: device)
                }
            } else {
                logger.error(
                    "Can't parse response for \(characteristic): \(String(describing: characteristic.value?.toHex()))"
                )

                if let error = error {
                    completeRequest(with: .failure(LedgerError.internalTransport(error: error)), device: device)
                } else {
                    let error = LedgerError.unexpectedData("Unexpected empty response from device")
                    completeRequest(with: .failure(error), device: device)
                }
            }
        }
    }
}
