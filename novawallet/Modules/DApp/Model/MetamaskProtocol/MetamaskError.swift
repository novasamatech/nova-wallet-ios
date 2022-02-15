import Foundation

struct MetamaskError {
    let code: Int
    let message: String
}

extension MetamaskError {
    static var noChainSwitch: MetamaskError {
        MetamaskError(code: 4902, message: "can't switch chain")
    }

    static var rejected: MetamaskError {
        MetamaskError(code: 4001, message: "Rejected")
    }

    static func invalidParams(with message: String) -> MetamaskError {
        MetamaskError(code: -32602, message: message)
    }

    static func internalError(with message: String) -> MetamaskError {
        MetamaskError(code: -32603, message: message)
    }
}
