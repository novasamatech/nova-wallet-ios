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
    case version30 = "SubstrateDataModel30"
    case version31 = "SubstrateDataModel31"
    case version32 = "SubstrateDataModel32"
    case version33 = "SubstrateDataModel33"
    case version34 = "SubstrateDataModel34"
    case version35 = "SubstrateDataModel35"
    case version36 = "SubstrateDataModel36"
    case version37 = "SubstrateDataModel37"
    case version38 = "SubstrateDataModel38"

    static var current: SubstrateStorageVersion {
        allCases.last!
    }

    var nextVersion: SubstrateStorageVersion? {
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
        case .version16: .version17
        case .version17: .version18
        case .version18: .version19
        case .version19: .version20
        case .version20: .version21
        case .version21: .version22
        case .version22: .version23
        case .version23: .version24
        case .version24: .version25
        case .version25: .version26
        case .version26: .version27
        case .version27: .version28
        case .version28: .version29
        case .version29: .version30
        case .version30: .version31
        case .version31: .version32
        // we have broken migration from 32 to 33
        case .version32: .version34
        case .version33: .version34
        case .version34: .version35
        case .version35: .version36
        case .version36: .version37
        case .version37: .version38
        case .version38: nil
        }
    }
}
