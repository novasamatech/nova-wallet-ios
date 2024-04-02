import Foundation

extension CloudBackup {
    struct Available: Equatable {
        static func == (lhs: CloudBackup.Available, rhs: CloudBackup.Available) -> Bool {
            lhs.cloudId.equals(to: rhs.cloudId)
        }

        let cloudId: CloudIdentifiable
    }

    enum Availability: Equatable {
        case notDetermined
        case unavailable
        case available(Available)
    }
}
