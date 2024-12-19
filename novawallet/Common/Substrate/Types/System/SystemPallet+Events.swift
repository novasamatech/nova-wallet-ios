import Foundation

extension SystemPallet {
    static var extrinsicSuccessEventPath: EventCodingPath {
        .init(moduleName: name, eventName: "ExtrinsicSuccess")
    }

    static var extrinsicFailedEventPath: EventCodingPath {
        .init(moduleName: name, eventName: "ExtrinsicFailed")
    }
}
