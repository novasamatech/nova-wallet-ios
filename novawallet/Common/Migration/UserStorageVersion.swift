import Foundation

enum UserStorageVersion: String, CaseIterable {
    case version1 = "UserDataModel"
    case version2 = "MultiassetUserDataModel"
    case version3 = "MultiassetUserDataModel2"
    case version4 = "MultiassetUserDataModel3"
    case version5 = "MultiassetUserDataModel4"
    case version6 = "MultiassetUserDataModel5"
    case version7 = "MultiassetUserDataModel6"
    case version8 = "MultiassetUserDataModel7"
    case version9 = "MultiassetUserDataModel8"
    case version10 = "MultiassetUserDataModel9"

    static var current: UserStorageVersion {
        guard let currentVersion = allCases.last else {
            fatalError("Unable to find current storage version")
        }

        return currentVersion
    }

    func nextVersion() -> UserStorageVersion? {
        switch self {
        case .version1:
            return .version2
        case .version2:
            return .version3
        case .version3:
            return .version4
        case .version4:
            return .version5
        case .version5:
            return .version6
        case .version6:
            return .version7
        case .version7:
            return .version8
        case .version8:
            return .version9
        case .version9:
            return .version10
        case .version10:
            return nil
        }
    }
}
