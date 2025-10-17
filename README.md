### Nova Wallet iOS - Next gen mobile app for Polkadot & Kusama ecosystem

[![](https://img.shields.io/twitter/follow/NovaWalletApp?label=Follow&style=social)](https://twitter.com/NovaWalletApp)

![logo](/docs/Nova_GitHub.png)

## About
Next gen application for Polkadot & Kusama ecosystem, transparent & community-oriented, focused on convenient UX/UI, fast performance & security.
Nova Wallet aims to provide as many Polkadot ecosystem features as possible in a form of mobile app, unbiased to any network & without any restrictions/limits to the users.
Developed by former Fearless Wallet team & based on open source work under Apache 2.0 license.

## Requirements

### System Requirements
- **Xcode**: 16.1+ (recommended)
- **iOS Deployment Target**: 16.0+
- **Swift**: 5.9+

### Development Tools
- **Homebrew**: For package management
- **Mint**: For Swift tool management
- **Generamba**: For VIPER module generation
- **Ruby**: For Generamba (comes with macOS)

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/nova-wallet/nova-wallet-ios.git
cd nova-wallet-ios
```

### 2. Install Dependencies

#### Install Homebrew (if not already installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### Install Project Dependencies
```bash
# Install Homebrew packages
brew bundle

# Install Mint tools (SwiftLint, SwiftFormat, Sourcery)
mint bootstrap
```

#### Install Generamba
```bash
# Install Generamba for VIPER module generation
gem install generamba
```

### 3. Open the Project
```bash
# Open the Xcode project
open novawallet.xcodeproj
```

### 4. Build and Run
1. Select the `novawallet` scheme
2. Choose your target device or simulator
3. Press `Cmd + R` to build and run

## Development

### Code Generation

#### Generate New VIPER Modules
Use the provided script to generate new VIPER modules:

```bash
# Make the script executable
chmod +x generamba-module.sh

# Generate a new module (replace 'ModuleName' with your desired name)
./generamba-module.sh ModuleName
```

This will create a complete VIPER module structure in `novawallet/Modules/` with:
- View Controller
- Presenter
- Interactor
- Wireframe
- Protocols
- Tests

#### Manual Generamba Usage
```bash
# Install templates
generamba template install

# Generate module manually
generamba gen ModuleName viper-code-layout
```

### Code Quality Tools

The project uses several code quality tools managed by Mint:

- **SwiftLint**: Code style and convention enforcement
- **SwiftFormat**: Automatic code formatting
- **Sourcery**: Code generation and boilerplate reduction

These tools are automatically installed via `mint bootstrap` and configured in the project.

### Project Structure

```
novawallet/
├── Common/           # Shared utilities and extensions
├── Modules/          # VIPER modules (generated with Generamba)
├── Assets.xcassets/  # App assets and images
├── Configs/          # Build configurations
└── Resources/        # Additional resources
```

## License
Nova Wallet iOS is available under the Apache 2.0 license. See the LICENSE file for more info.
© Novasama Technologies GmbH 2023