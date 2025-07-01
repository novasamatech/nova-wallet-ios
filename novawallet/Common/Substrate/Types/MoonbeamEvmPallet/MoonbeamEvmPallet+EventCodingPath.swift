import Foundation

extension MoonbeamEvmPallet {
    static var logEventPath: EventCodingPath {
        EventCodingPath(moduleName: Self.name, eventName: "Log")
    }
}
