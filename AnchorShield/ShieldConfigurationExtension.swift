import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Supplies the screen iOS shows when a blocked app is opened.
///
/// This runs in a separate process, launched on demand by the system. It gets
/// no access to Anchor's `UserDefaults` without a shared app group, and it
/// cannot start an NFC scan — extensions have no such capability. Its only job
/// is to tell the user what to do: go find the puck.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        anchorShield(
            subtitle: "Tap your Anchor puck to unlock this app."
        )
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        anchorShield(
            subtitle: "Tap your Anchor puck to unlock this app."
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        anchorShield(
            subtitle: "Tap your Anchor puck to unlock this site."
        )
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        anchorShield(
            subtitle: "Tap your Anchor puck to unlock this site."
        )
    }

    /// One look for every shield, so the block reads as a single consistent
    /// wall rather than four subtly different ones.
    private func anchorShield(subtitle: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: nil,
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: "Focus is on",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor.white.withAlphaComponent(0.75)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "OK",
                color: .black
            ),
            primaryButtonBackgroundColor: .white
        )
    }
}
