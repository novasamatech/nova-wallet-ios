import Foundation

class TransferConfirmWireframe: TransferConfirmWireframeProtocol {}

final class EvmTransferConfirmWireframe: TransferConfirmWireframe, EvmValidationErrorPresentable {}
