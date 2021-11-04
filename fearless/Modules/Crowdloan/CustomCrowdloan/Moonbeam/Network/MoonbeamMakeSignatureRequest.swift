import Foundation

struct MoonbeamMakeSignatureRequest {
    let address: String
    let previousTotalContribution: String
    let contribution: String
    let guid: String
}

extension MoonbeamMakeSignatureRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case address
        case previousTotalContribution = "previous-total-contribution"
        case contribution
        case guid
    }
}
