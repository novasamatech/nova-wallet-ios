import Foundation
import CoreBluetooth

protocol LedgerDeviceProtocol {
    var identifier: UUID { get }
    var name: String { get }
}

final class BluetoothLedgerDevice: LedgerDeviceProtocol {
    typealias WriteCommand = () -> Void
    typealias ResponseCompletion = (Result<Data, Error>) -> Void

    let peripheral: CBPeripheral

    var name: String {
        peripheral.name ?? "Unknown device"
    }

    var identifier: UUID {
        peripheral.identifier
    }

    var readCharacteristic: CBCharacteristic?
    var writeCharacteristic: CBCharacteristic?
    var notifyCharacteristic: CBCharacteristic?

    var writeCommand: WriteCommand?
    var responseCompletion: ResponseCompletion?

    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
    }
}

struct SupportedBluetoothDevice {
    let uuid: CBUUID
    let notifyUuid: CBUUID
    let writeUuid: CBUUID
}

extension SupportedBluetoothDevice {
    static var ledgerNanoX: SupportedBluetoothDevice {
        SupportedBluetoothDevice(
            uuid: CBUUID(string: "13D63400-2C97-0004-0000-4C6564676572"),
            notifyUuid: CBUUID(string: "13D63400-2C97-0004-0001-4C6564676572"),
            writeUuid: CBUUID(string: "13D63400-2C97-0004-0002-4C6564676572")
        )
    }
}
