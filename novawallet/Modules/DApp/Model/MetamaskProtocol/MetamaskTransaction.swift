import Foundation

struct MetamaskTransaction: Codable {
    /**
     * 20 Bytes hex - The address the transaction is send from.
     */
    let from: String

    /**
     *  20 Bytes - (optional) The address the transaction is directed to.
     */
    // swiftlint:disable:next identifier_name
    let to: String?

    /**
     *  (optional, default: 90000) gas provided for the transaction execution.
     *  It will return unused gas.
     */
    let gas: String?

    /**
     *  (optional, default: To-Be-Determined) Integer (in hex) of the gasPrice used for each paid gas
     */
    let gasPrice: String?

    /**
     * (optional) Integer (in hex) of the value sent with this transaction
     */
    let value: String?

    /**
     * Optional the compiled code of a contract OR the hash of the invoked method signature and encoded
     * parameters. For details see Ethereum Contract ABI
     */
    let data: String?
}
