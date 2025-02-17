// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum LocalizedString {
  /// You will be able to access premium features again after these are paid.
  public static var delinquentDescription: String { return LocalizedString.tr("Localizable", "delinquent_description") }
  /// You will be able to access premium features again after these are paid. For now, we are reconnecting to the fastest Free plan server available.
  public static var delinquentReconnectionDescription: String { return LocalizedString.tr("Localizable", "delinquent_reconnection_description") }
  /// Your VPN account has pending invoices
  public static var delinquentTitle: String { return LocalizedString.tr("Localizable", "delinquent_title") }
  /// From server:
  public static var fromServerTitle: String { return LocalizedString.tr("Localizable", "from_server_title") }
  /// Please disconnect another device to connect to this one.
  public static var maximumDeviceLimit: String { return LocalizedString.tr("Localizable", "maximum_device_limit") }
  /// Please disconnect another device to connect to this one or upgrade to %@
  public static func maximumDevicePlanLimitPart1(_ p1: Any) -> String {
    return LocalizedString.tr("Localizable", "maximum_device_plan_limit_part_1", String(describing: p1))
  }
  /// Plural format key: " to get up to %#@num_devices@ connected at the same time."
  public static func maximumDevicePlanLimitPart2(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "maximum_device_plan_limit_part_2", p1)
  }
  /// You have reached your maximum device limit
  public static var maximumDeviceTitle: String { return LocalizedString.tr("Localizable", "maximum_device_title") }
  /// Cancel
  public static var modalsCommonCancel: String { return LocalizedString.tr("Localizable", "modals_common_cancel") }
  /// Learn more
  public static var modalsCommonLearnMore: String { return LocalizedString.tr("Localizable", "modals_common_learn_more") }
  /// Next
  public static var modalsCommonNext: String { return LocalizedString.tr("Localizable", "modals_common_next") }
  /// Activate Secure Core
  public static var modalsDiscourageSecureCoreActivate: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_activate") }
  /// Don’t show again
  public static var modalsDiscourageSecureCoreDontShow: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_dont_show") }
  /// Secure Core offers the highest level of security and privacy, but it may reduce your internet speed. If you need more performance, you can disable Secure Core.
  public static var modalsDiscourageSecureCoreSubtitle: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_subtitle") }
  /// A note about speed...
  public static var modalsDiscourageSecureCoreTitle: String { return LocalizedString.tr("Localizable", "modals_discourage_secure_core_title") }
  /// Upgrade
  public static var modalsGetPlus: String { return LocalizedString.tr("Localizable", "modals_get_plus") }
  /// Proton VPN's strict no-log policy is certified by an external audit.
  public static var modalsNoLogsExternalAudit: String { return LocalizedString.tr("Localizable", "modals_no_logs_external_audit") }
  /// We do not log your internet activity
  public static var modalsNoLogsLogActivity: String { return LocalizedString.tr("Localizable", "modals_no_logs_log_activity") }
  /// Proton VPN is privacy first
  public static var modalsNoLogsPrivacyFirst: String { return LocalizedString.tr("Localizable", "modals_no_logs_privacy_first") }
  /// We do not share any data with third parties
  public static var modalsNoLogsThirdParties: String { return LocalizedString.tr("Localizable", "modals_no_logs_third_parties") }
  /// No logs and Swiss-based
  public static var modalsNoLogsTitle: String { return LocalizedString.tr("Localizable", "modals_no_logs_title") }
  /// Browse at the highest speeds (10 Gbps)
  public static var modalsUpsellAllCountriesFeatureHighSpeed: String { return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_highSpeed") }
  /// Plural format key: "%#@VARIABLE@"
  public static func modalsUpsellAllCountriesFeatureMultipleDevices(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_multipleDevices", p1)
  }
  /// Block ads and malware with NetShield
  public static var modalsUpsellAllCountriesFeatureNetshield: String { return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_netshield") }
  /// Access global streaming services
  public static var modalsUpsellAllCountriesFeatureStreaming: String { return LocalizedString.tr("Localizable", "modals_upsell_all_countries_feature_streaming") }
  /// Plural format key: "Access over %#@num_servers@ in %#@num_countries@"
  public static func modalsUpsellAllCountriesTitle(_ p1: Int, _ p2: Int) -> String {
    return LocalizedString.tr("Localizable", "modals_upsell_all_countries_title", p1, p2)
  }
  /// And many more premium features
  public static var modalsUpsellFeaturesFooter: String { return LocalizedString.tr("Localizable", "modals_upsell_features_footer") }
  /// Moderate NAT, also known as Nat Type 2, can improve your online experience with various applications and online video games.
  /// 
  /// Unlock this and other features with a Plus plan.
  public static var modalsUpsellFeaturesModerateNatSubtitle: String { return LocalizedString.tr("Localizable", "modals_upsell_features_moderate_nat_subtitle") }
  /// Have advanced or professional computing needs that require non-standard ports?
  /// 
  /// Upgrade to VPN Plus to access this and other premium features.
  public static var modalsUpsellFeaturesSafeModeSubtitle: String { return LocalizedString.tr("Localizable", "modals_upsell_features_safe_mode_subtitle") }
  /// When you upgrade to VPN Plus
  public static var modalsUpsellFeaturesSubtitle: String { return LocalizedString.tr("Localizable", "modals_upsell_features_subtitle") }
  /// What is Moderate NAT?
  public static var modalsUpsellModerateNatLearnMore: String { return LocalizedString.tr("Localizable", "modals_upsell_moderate_nat_learn_more") }
  /// Enable Moderate NAT
  public static var modalsUpsellModerateNatTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_moderate_nat_title") }
  /// Block ads and trackers
  public static var modalsUpsellNetShieldAds: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_ads") }
  /// Browse at the highest speeds
  public static var modalsUpsellNetShieldHighSpeed: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_highSpeed") }
  /// Protect your device from malware
  public static var modalsUpsellNetShieldMalware: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_malware") }
  /// Enjoy ad-free browsing with NetShield
  public static var modalsUpsellNetShieldTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_net_shield_title") }
  /// Learn More
  public static var modalsUpsellSafeModeLearnMore: String { return LocalizedString.tr("Localizable", "modals_upsell_safe_mode_learn_more") }
  /// Allow traffic to non-standard ports
  public static var modalsUpsellSafeModeTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_safe_mode_title") }
  /// Protect yourself from network attacks
  public static var modalsUpsellSecureCoreAttacks: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_attacks") }
  /// Add another layer of encryption to your VPN connection
  public static var modalsUpsellSecureCoreLayer: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_layer") }
  /// Route through ultra secure servers in Switzerland, Sweden, and Iceland
  public static var modalsUpsellSecureCoreRoute: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_route") }
  /// Double the encryption with Secure Core
  public static var modalsUpsellSecureCoreTitle: String { return LocalizedString.tr("Localizable", "modals_upsell_secure_core_title") }
  /// Not now
  public static var modalsUpsellStayFree: String { return LocalizedString.tr("Localizable", "modals_upsell_stay_free") }
  /// Got it
  public static var newPlansBrandGotIt: String { return LocalizedString.tr("Localizable", "new_plans_brand_got_it") }
  /// Introducing Proton’s refreshed look.
  /// Many services, one mission. Welcome to an internet where privacy is the default.
  public static var newPlansBrandSubtitle: String { return LocalizedString.tr("Localizable", "new_plans_brand_subtitle") }
  /// Updated Proton, unified protection
  public static var newPlansBrandTitle: String { return LocalizedString.tr("Localizable", "new_plans_brand_title") }
  /// Your subscription has been downgraded.
  public static var subscriptionExpiredDescription: String { return LocalizedString.tr("Localizable", "subscription_expired_description") }
  /// Your subscription has been downgraded, so we are reconnecting to the fastest available server.
  public static var subscriptionExpiredReconnectionDescription: String { return LocalizedString.tr("Localizable", "subscription_expired_reconnection_description") }
  /// Your VPN subscription plan has expired
  public static var subscriptionExpiredTitle: String { return LocalizedString.tr("Localizable", "subscription_expired_title") }
  /// Plural format key: "Hundreds of servers in %#@num_countries@"
  public static func subscriptionUpgradeOption1(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "subscription_upgrade_option1", p1)
  }
  /// Plural format key: "Connect up to %#@num_devices@ at the same time"
  public static func subscriptionUpgradeOption2(_ p1: Int) -> String {
    return LocalizedString.tr("Localizable", "subscription_upgrade_option2", p1)
  }
  /// Advanced features: NetShield, Secure Core, Tor, P2P
  public static var subscriptionUpgradeOption3: String { return LocalizedString.tr("Localizable", "subscription_upgrade_option3") }
  /// To server:
  public static var toServerTitle: String { return LocalizedString.tr("Localizable", "to_server_title") }
  /// Update My Billing
  public static var updateBilling: String { return LocalizedString.tr("Localizable", "update_billing") }
  /// Upgrade Again
  public static var upgradeAgain: String { return LocalizedString.tr("Localizable", "upgrade_again") }
  /// No Thanks
  public static var upgradeNoThanks: String { return LocalizedString.tr("Localizable", "upgrade_no_thanks") }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension LocalizedString {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = localizeStringAndFallbackToEn(key, table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
