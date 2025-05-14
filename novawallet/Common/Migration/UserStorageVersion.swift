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
    case version11 = "MultiassetUserDataModel10"
    case version12 = "MultiassetUserDataModel11"
    case version13 = "MultiassetUserDataModel12"
    case version14 = "MultiassetUserDataModel13"
    case version15 = "MultiassetUserDataModel14"
    case version16 = "MultiassetUserDataModel15"

    static var current: UserStorageVersion {
        guard let currentVersion = allCases.last else {
            fatalError("Unable to find current storage version")
        }

        return currentVersion
    }

    func nextVersion() -> UserStorageVersion? {
        switch self {
        case .version1: .version2
        case .version2: .version3
        case .version3: .version4
        case .version4: .version5
        case .version5: .version6
        case .version6: .version7
        case .version7: .version8
        case .version8: .version9
        case .version9: .version10
        case .version10: .version11
        case .version11: .version12
        case .version12: .version13
        case .version13: .version14
        case .version14: .version15
        case .version15: .version16
        case .version16: nil
        }
    }
}
