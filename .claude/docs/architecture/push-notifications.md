# Push Notifications

Push is delivered through Firebase Cloud Messaging, rendered by a notification service extension, and
routed inside the app to a destination screen.

## Pieces

| Piece                                    | Where                                            |
|------------------------------------------|--------------------------------------------------|
| Registration + settings sync             | `Common/Services/Web3AlertService/`              |
| APNS token plumbing                      | `AppDelegate` → `PushNotificationsServiceFacade.updateAPNS(token:)` |
| Rich content rendering                   | `NovaPushNotificationServiceExtension/`          |
| In-app handling / navigation             | `Common/PushHandling/`                           |
| User-facing settings UI                  | `Modules/Notifications/`                         |

## Registration & Sync — `PushNotificationsServiceFacade`

`PushNotificationsServiceFacade.shared` is an `ApplicationServiceProtocol` member of
`ServiceCoordinator`. It composes:

| Sub-service                        | Role                                                          |
|------------------------------------|---------------------------------------------------------------|
| `PushNotificationsStatusService`   | Authorisation status; observable via `subscribeStatus(_:closure:)` |
| `Web3AlertsSyncService`            | Pushes the user's alert settings to the backend (Firestore)   |
| `PushNotificationsTopicService`    | FCM topic subscriptions (announcements, chain-wide events)    |
| `Web3AlertsWalletsUpdateService`   | Keeps the backend's wallet/address list in sync               |

`syncWallets()` is called from `ServiceCoordinator.updateOnWalletChange(for:)` and
`updateOnWalletRemove()` — any code path that adds or removes a wallet must go through the mediator
so this stays consistent (see architecture/wallets-accounts.md).

Firebase is initialised through `FirebaseHolder`; App Check uses
`FirebaseAppCheckProviderFactory` with a debug provider behind `#if F_APPCHECK_DEBUG`.
`GoogleService-Info.plist` is copied per configuration by a build phase (Dev plist for
Debug/Dev/Staging, Release plist for Release).

## Notification Service Extension

`NovaPushNotificationServiceExtension/` turns a minimal push payload into readable, localized
content. It is a separate target with its own `R.generated.swift` and `.lproj` catalogs, and shares
the app group container for settings/chain data.

`PushNotificationHandlersFactory` picks a handler by notification type:

```
Handlers/
  Transfers/     Staking/     Governance/     Multisig/     Technical/
  CommonHandler.swift
```

Handlers resolve chain/asset metadata, format amounts, and produce a `NotificationContentResult`.

Because it is a separate target, the extension cannot use app-target types: keep anything shared
(models, chain access, formatting) in code that both targets compile, and add new strings to **both**
localization catalogs.

## In-App Handling

`PushNotificationHandlingService.shared.handle(userInfo:)` is called from
`AppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)`.

- `PushNotificationsHandlerFactory` builds the handler for the payload type.
- `PushNotificationOpenScreenFacade` performs the navigation; handlers that need a specific wallet
  use `WalletSelectingNotificationHandling` to switch wallets first, and `ChainAcquiring` to wait
  for the chain to become available.
- Navigation must be safe when the UI is not ready yet (cold start, pincode screen). Handlers defer
  until the main flow exists rather than pushing onto a nil navigation stack.

## Settings UI

`Modules/Notifications/` provides the per-category settings: wallet selection, staking rewards,
governance tracks (`GovernanceTracksSettings`), announcements. Changes are persisted and pushed to
the backend by `Web3AlertsSyncService`; `PushNotification.AllSettings` is the payload saved through
`PushNotificationsServiceFacade.save(settings:completion:)`.

## Hard Rules

1. **A new notification type needs three changes**: an extension handler (rich content), an in-app
   handler (navigation), and settings support if the user can toggle it.
2. **Localize in both targets.** The extension has its own strings catalog; missing keys there ship
   as untranslated English.
3. **Never assume the app is running.** In-app handlers must work from a cold start and while the
   security/pincode gate is on screen.
4. **Wallet/topic sync is driven by `ServiceCoordinator` hooks** — don't call the sync services
   directly from a module.
5. **No sensitive data in payloads or logs.** Push content is rendered from ids plus local data, not
   from server-provided secrets.
