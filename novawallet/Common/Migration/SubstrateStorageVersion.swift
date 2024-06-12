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
    case version12 = "SubstrateDataModel12"
    case version13 = "SubstrateDataModel13"
    case version14 = "SubstrateDataModel14"
    case version15 = "SubstrateDataModel15"
    case version16 = "SubstrateDataModel16"
    case version17 = "SubstrateDataModel17"
    case version18 = "SubstrateDataModel18"
    case version19 = "SubstrateDataModel19"
    case version20 = "SubstrateDataModel20"
    case version21 = "SubstrateDataModel21"
    case version22 = "SubstrateDataModel22"
    case version23 = "SubstrateDataModel23"
    case version24 = "SubstrateDataModel24"
    case version25 = "SubstrateDataModel25"
    case version26 = "SubstrateDataModel26"
    case version27 = "SubstrateDataModel27"
    case version28 = "SubstrateDataModel28"
    case version29 = "SubstrateDataModel29"

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
            return .version12
        case .version12:
            return .version13
        case .version13:
            return .version14
        case .version14:
            return .version15
        case .version15:
            return .version16
        case .version16:
            return .version17
        case .version17:
            return .version18
        case .version18:
            return .version19
        case .version19:
            return .version20
        case .version20:
            return .version21
        case .version21:
            return .version22
        case .version22:
            return .version23
        case .version23:
            return .version24
        case .version24:
            return .version25
        case .version25:
            return .version26
        case .version26:
            return .version27
        case .version27:
            return .version28
        case .version28:
            return .version29
        case .version29:
            return nil
        }
    }
}
