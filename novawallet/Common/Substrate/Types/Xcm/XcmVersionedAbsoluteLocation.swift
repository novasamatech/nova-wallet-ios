import Foundation
import SubstrateSdk

extension Xcm {
    enum VersionedAbsoluteLocationError: Error {
        case versionMismatch
    }

    // swiftlint:disable identifier_name
    enum VersionedAbsoluteLocation {
        case V1(Xcm.AbsoluteLocation)
        case V2(Xcm.AbsoluteLocation)
        case V3(XcmV3.AbsoluteLocation)
        case V4(XcmV4.AbsoluteLocation)

        var version: Xcm.Version {
            switch self {
            case .V1:
                return .V1
            case .V2:
                return .V2
            case .V3:
                return .V3
            case .V4:
                return .V4
            }
        }
    }
}

extension Xcm.VersionedAbsoluteLocation {
    init(paraId: ParaId?, version: Xcm.Version) {
        switch version {
        case .V0, .V1:
            let model = Xcm.AbsoluteLocation(paraId: paraId)
            self = .V1(model)
        case .V2:
            let model = Xcm.AbsoluteLocation(paraId: paraId)
            self = .V2(model)
        case .V3:
            let model = XcmV3.AbsoluteLocation(paraId: paraId)
            self = .V3(model)
        case .V4:
            let model = XcmV4.AbsoluteLocation(paraId: paraId)
            self = .V4(model)
        }
    }

    static func createWithRawPath(_ path: JSON, version: Xcm.Version) throws -> Xcm.VersionedAbsoluteLocation {
        switch version {
        case .V0, .V1:
            let model = try Xcm.AbsoluteLocation.createWithRawPath(path)
            return .V1(model)
        case .V2:
            let model = try Xcm.AbsoluteLocation.createWithRawPath(path)
            return .V2(model)
        case .V3:
            let model = try XcmV3.AbsoluteLocation.createWithRawPath(path)
            return .V3(model)
        case .V4:
            let model = try XcmV4.AbsoluteLocation.createWithRawPath(path)
            return .V4(model)
        }
    }

    func appendingAccountId(
        _ accountId: AccountId,
        isEthereumBase: Bool
    ) -> Xcm.VersionedAbsoluteLocation {
        switch self {
        case let .V1(absoluteLocation):
            let newLocation = absoluteLocation.appendingAccountId(accountId, isEthereumBase: isEthereumBase)
            return .V1(newLocation)
        case let .V2(absoluteLocation):
            let newLocation = absoluteLocation.appendingAccountId(accountId, isEthereumBase: isEthereumBase)
            return .V2(newLocation)
        case let .V3(absoluteLocation):
            let newLocation = absoluteLocation.appendingAccountId(accountId, isEthereumBase: isEthereumBase)
            return .V3(newLocation)
        case let .V4(absoluteLocation):
            let newLocation = absoluteLocation.appendingAccountId(accountId, isEthereumBase: isEthereumBase)
            return .V4(newLocation)
        }
    }

    func fromPointOfView(location: Xcm.VersionedAbsoluteLocation) throws -> Xcm.VersionedMultilocation {
        switch (self, location) {
        case let (.V1(current), .V1(target)):
            let newLocation = current.fromPointOfView(location: target)
            return .V1(newLocation)
        case let (.V2(current), .V2(target)):
            let newLocation = current.fromPointOfView(location: target)
            return .V2(newLocation)
        case let (.V3(current), .V3(target)):
            let newLocation = current.fromPointOfView(location: target)
            return .V3(newLocation)
        case let (.V4(current), .V4(target)):
            let newLocation = current.fromPointOfView(location: target)
            return .V4(newLocation)
        default:
            throw Xcm.VersionedAbsoluteLocationError.versionMismatch
        }
    }
}
