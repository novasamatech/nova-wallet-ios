import Foundation
import SubstrateSdk

struct EventRecord: Decodable {
    enum CodingKeys: String, CodingKey {
        case phase
        case event
    }

    let phase: Phase
    let event: Event

    init(from decoder: Decoder) throws {
        if let keyedContainer = try? decoder.container(keyedBy: CodingKeys.self) {
            phase = try keyedContainer.decode(Phase.self, forKey: .phase)
            event = try keyedContainer.decode(Event.self, forKey: .event)
        } else {
            var unkeyedContainer = try decoder.unkeyedContainer()
            phase = try unkeyedContainer.decode(Phase.self)
            event = try unkeyedContainer.decode(Event.self)
        }
    }
}

extension EventRecord {
    var extrinsicIndex: UInt32? {
        if case let .applyExtrinsic(index) = phase {
            return index
        } else {
            return nil
        }
    }
}

enum Phase: Decodable {
    static let extrinsicField = "ApplyExtrinsic"
    static let finalizationField = "Finalization"
    static let initializationField = "Initialization"

    case applyExtrinsic(index: UInt32)
    case finalization
    case initialization

    var isInitialization: Bool {
        switch self {
        case .initialization:
            return true
        case .applyExtrinsic, .finalization:
            return false
        }
    }

    var isFinalization: Bool {
        switch self {
        case .finalization:
            return true
        case .applyExtrinsic, .initialization:
            return false
        }
    }

    var isExtrinsicApplication: Bool {
        switch self {
        case .applyExtrinsic:
            return true
        case .finalization, .initialization:
            return false
        }
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Phase.extrinsicField:
            let index = try container.decode(StringScaleMapper<UInt32>.self).value
            self = .applyExtrinsic(index: index)
        case Phase.finalizationField:
            self = .finalization
        case Phase.initializationField:
            self = .initialization
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected phase"
            )
        }
    }
}

struct Event: Decodable {
    let moduleIndex: UInt8
    let eventIndex: UInt32
    let params: JSON

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        moduleIndex = try unkeyedContainer.decode(UInt8.self)
        eventIndex = try unkeyedContainer.decode(UInt32.self)
        params = try unkeyedContainer.decode(JSON.self)
    }
}

struct ExtrinsicFailedEventParams: Decodable {
    let dispatchError: DispatchExtrinsicError

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        dispatchError = try unkeyedContainer.decode(DispatchExtrinsicError.self)
    }
}

enum DispatchExtrinsicError: Decodable, Error {
    struct ModuleError: Decodable {
        @StringCodable var index: UInt8
        @BytesCodable var error: Data
    }

    case module(ModuleError)
    case other(String)

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        let module = try unkeyedContainer.decode(String.self)

        switch module {
        case "Module":
            let moduleError = try unkeyedContainer.decode(ModuleError.self)
            self = .module(moduleError)
        default:
            self = .other(module)
        }
    }
}
