import Foundation_iOS
import Keystore_iOS

extension CloudBackupCreateViewFactory {
    static func createViewForUpdatePassword(password: String) -> CloudBackupCreateViewProtocol? {
        let wireframe = CloudBackupUpdatePasswordWireframe(oldPassword: password)

        let flow: CloudBackupSetupPasswordFlow = .changePassword

        let presenter = CloudBackupCreatePasswordPresenter(
            wireframe: wireframe,
            hintsViewModelFactory: CloudBackPasswordViewModelFactory(flow: flow),
            passwordValidator: CloudBackupPasswordValidator(),
            localizationManager: LocalizationManager.shared
        )

        let view = CloudBackupCreateViewController(
            presenter: presenter,
            flow: flow,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    static func createConfirmViewForUpdatePassword(
        for newPassword: String,
        oldPassword: String
    ) -> CloudBackupCreateViewProtocol? {
        let interactor = createPasswordChangeInteractor(for: oldPassword)
        let wireframe = CloudBackupUpdatePasswordConfirmWireframe()

        let flow: CloudBackupSetupPasswordFlow = .confirmPassword

        let presenter = CloudBackupConfirmPasswordPresenter(
            interactor: interactor,
            wireframe: wireframe,
            hintsViewModelFactory: CloudBackPasswordViewModelFactory(flow: flow),
            passwordValidator: CloudBackupPasswordValidator(),
            passwordToConfirm: newPassword,
            localizationManager: LocalizationManager.shared
        )

        let view = CloudBackupCreateViewController(
            presenter: presenter,
            flow: flow,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPasswordChangeInteractor(for password: String) -> CloudBackupUpdatePasswordInteractor {
        let serviceFacade = CloudBackupServiceFacade.createFacade()
        return CloudBackupUpdatePasswordInteractor(
            oldPassword: password,
            serviceFacade: serviceFacade,
            syncMetadataManager: CloudBackupSyncMetadataManager(
                settings: SettingsManager.shared,
                keystore: Keychain()
            )
        )
    }
}
