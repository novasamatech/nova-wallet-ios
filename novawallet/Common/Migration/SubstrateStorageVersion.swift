enum SubstrateStorageVersion: String, CaseIterable {
    case version1 = "SubstrateDataModel"
    case version2 = "SubstrateDataModel2"

    static var current: SubstrateStorageVersion {
        allCases.last!
    }

    var nextVersion: SubstrateStorageVersion? {
        switch self {
        case .version1:
            return .version2
        case .version2:
            return nil
        }
    }
}
