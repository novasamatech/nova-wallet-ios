import SubstrateSdk

extension Staking {
    struct SetController: Codable {
        let controller: MultiAddress

        static let path = CallCodingPath(moduleName: Staking.module, callName: "set_controller")

        static func isDeprecated(for codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
            guard let callMetadata = codingFactory.getCall(for: path) else {
                return false
            }

            return !callMetadata.hasArgument(named: "controller")
        }

        static func appendCall(
            for controller: MultiAddress,
            codingFactory: RuntimeCoderFactoryProtocol
        ) throws -> ExtrinsicBuilderClosure {
            let isDeprecated = isDeprecated(for: codingFactory)

            return { builder in
                if isDeprecated {
                    return try builder.adding(
                        call: RuntimeCall(moduleName: path.moduleName, callName: path.callName)
                    )
                } else {
                    let call = SetController(controller: controller)

                    return try builder.adding(
                        call: RuntimeCall(moduleName: path.moduleName, callName: path.callName, args: call)
                    )
                }
            }
        }
    }
}
