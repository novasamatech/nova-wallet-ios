enum SubstrateStorageVersion: String, CaseIterable {
    case version1 = "SubstrateDataModel"
    case version2 = "SubstrateDataModel2"
    case version3 = "SubstrateDataModel3"
    case version4 = "SubstrateDataModel4"
    case version5 = "SubstrateDataModel5"
    case version6 = "SubstrateDataModel6"
    case version7 = "SubstrateDataModel7"
    case version8 = "SubstrateDataModel8"
    case version9 = "SubstrateDataModel9"
    case version10 = "SubstrateDataModel10"
    case version11 = "SubstrateDataModel11"

    static var current: SubstrateStorageVersion {
        allCases.last!
    }

    var nextVersion: SubstrateStorageVersion? {
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
            return .version11
        case .version11:
            return nil
        }
    }
}
