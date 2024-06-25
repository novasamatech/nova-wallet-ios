import Foundation

protocol CloudIdentifiable {
    func equals(to other: CloudIdentifiable) -> Bool
}

struct ICloudIdentifier: CloudIdentifiable {
    typealias IdType = NSCoding & NSCopying & NSObjectProtocol

    let cloudId: IdType

    func equals(to other: CloudIdentifiable) -> Bool {
        guard let otheriCloud = other as? ICloudIdentifier else {
            return false
        }

        return cloudId.isEqual(otheriCloud.cloudId)
    }
}
