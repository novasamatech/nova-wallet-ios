import Foundation
import CoreBluetooth

enum LedgerConnectionError: Error {
    case unauthorized
    case connection
    case deviceNotFound
    case deviceDisconnected
    case badResponse
}

protocol LedgerConnectionManagerProtocol: AnyObject {
    func start()
    func stop()
    func send(message: Data, deviceId: UUID, completion: @escaping (Result<Data, Error>) -> Void)
}

protocol LedgerConnectionManagerDelegate: AnyObject {
    func ledgerConnection(manager: LedgerConnectionManagerProtocol, didFailToConnect error: Error)
    func ledgerConnection(manager: LedgerConnectionManagerProtocol, didDiscover deviceId: UUID)
    func ledgerConnection(manager: LedgerConnectionManagerProtocol, didDisconnect deviceId: UUID, error: Error?)
}

final class LedgerConnectionManager: NSObject {
    private var centralManager: CBCentralManager?

    private var devices: [BluetoothLedgerDevice] = []

    private var supportedDevices: [SupportedBluetoothDevice] = [SupportedBluetoothDevice.ledgerNanoX]
    private var supportedDeviceUUIDs: [CBUUID] { supportedDevices.compactMap(\.uuid) }
    private var supportedDeviceNotifyUuids: [CBUUID] { supportedDevices.compactMap(\.notifyUuid) }

    weak var delegate: LedgerConnectionManagerDelegate?

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    private func removeDevices(peripheral: CBPeripheral) {
        devices.removeAll { $0.peripheral == peripheral }
    }

    private func bluetoothDevice(id: UUID) -> BluetoothLedgerDevice? {
        devices.first { $0.identifier == id }
    }

    func didDiscoverDevice(_ peripheral: CBPeripheral) {
        if bluetoothDevice(id: peripheral.identifier) == nil {
            let device = BluetoothLedgerDevice(peripheral: peripheral)
            devices.append(device)
            delegate?.ledgerConnection(manager: self, didDiscover: device.identifier)
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
            queue: DispatchQueue.main,
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

    func send(message: Data, deviceId: UUID, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let centralManager = centralManager, let device = bluetoothDevice(id: deviceId) else {
            completion(.failure(LedgerConnectionError.deviceNotFound))
            return
        }

        centralManager.connect(device.peripheral, options: nil)
        device.writeCommand = { [weak device] in
            if let characteristic = device?.writeCharacteristic {
                device?.responseCompletion = completion
                let data = APDUController.prepareAPDU(message: message)
                device?.peripheral.writeValue(data, for: characteristic, type: .withResponse)
            }
        }
    }
}

extension LedgerConnectionManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            centralManager?.retrieveConnectedPeripherals(withServices: supportedDeviceUUIDs).forEach { peripheral in
                didDiscoverDevice(peripheral)
            }
            centralManager?.scanForPeripherals(withServices: supportedDeviceUUIDs)
        case .unauthorized:
            delegate?.ledgerConnection(manager: self, didFailToConnect: LedgerConnectionError.unauthorized)
        default:
            delegate?.ledgerConnection(manager: self, didFailToConnect: LedgerConnectionError.connection)
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData _: [String: Any],
        rssi _: NSNumber
    ) {
        didDiscoverDevice(peripheral)
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(supportedDeviceUUIDs)
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard let device = bluetoothDevice(id: peripheral.identifier) else { return }

        device.responseCompletion?(.failure(LedgerConnectionError.deviceDisconnected))

        removeDevices(peripheral: peripheral)

        delegate?.ledgerConnection(manager: self, didDisconnect: device.identifier, error: error)
    }
}

extension LedgerConnectionManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        logger.debug("\(peripheral) did discover services with error: \(String(describing: error))")

        guard let services = peripheral.services else { return }

        for service in services { peripheral.discoverCharacteristics(nil, for: service) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        logger.debug("\(peripheral) did discover characteristics for \(service) with error: \(String(describing: error))")

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

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
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
            guard let responseCompletion = device.responseCompletion else { return }

            if let error = error {
                logger.error("Failed to update value for \(characteristic): \(error)")
                responseCompletion(.failure(error))
            }

            if let message = characteristic.value, let data = APDUController.parseAPDU(message: message) {
                responseCompletion(.success(data))
            } else {
                logger.error("Can't parse response for \(characteristic): \(String(describing: characteristic.value?.toHex()))")
                responseCompletion(.failure(LedgerConnectionError.badResponse))
            }

            device.responseCompletion = nil
        }
    }
}
