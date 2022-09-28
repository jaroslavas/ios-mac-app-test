workspace 'ProtonVPN'

# ignore all warnings from all pods
inhibit_all_warnings!

def proton_url
  'git@' + ENV["PROTON_GIT_URL"]
end

def proton_core_path
    proton_url + ':apple/shared/protoncore.git'
end

def proton_core_version
  '3.22.4'
end

def openvpn
  pod 'TunnelKit', :git => proton_url + ':apple/vpn/tunnelkit.git', :branch => 'develop'
end

def pm_automation
  pod 'pmtest', :git => proton_url + ':apple/shared/pmtestautomation.git', :commit => '579ef5f66deea4231784614d936956982f53ee30'
end

def keychain_access
  pod 'KeychainAccess', '3.2.1'
end

def reachability
  pod 'ReachabilitySwift', '5.0.0'
end

def sd_web_image
  pod 'SDWebImage', '5.12.6'
end

def vpn_core
    use_frameworks!        
    pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '7.16.0'
    reachability
    keychain_access
    
    # Checks code style and bad practices
    pod 'SwiftLint', '0.48.0'

    pod 'SwiftGen', '~> 6.5'

    # Certificates pinning
    pod 'TrustKit', :git => 'https://github.com/ProtonMail/TrustKit', :commit => '838fba789e01c9cabff77acea3fb7135f71a220f'
    
    openvpn

    # Core
    pod 'ProtonCore-Log', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-Doh', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-Services/Alamofire', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-Networking/Alamofire', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-Authentication/UsingCryptoVPN+Alamofire', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-Crypto-VPN', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-Payments/UsingCryptoVPN+Alamofire', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-UIFoundations-V5', :git => proton_core_path, :tag => proton_core_version

    # Third party pods
    sd_web_image
end    

abstract_target 'Core' do
    project 'libraries/vpncore/Core.xcodeproj'
    vpn_core

    target 'vpncore-ios' do       
        platform :ios, '14.0'
    end
    target 'vpncore-macos' do        
        platform :osx, '10.15'
    end
    target 'vpncore-iosTests' do
        platform :ios, '14.0'
        pod 'ProtonCore-TestingToolkit/UnitTests/Core', :git => proton_core_path, :tag => proton_core_version
    end
    target 'vpncore-macosTests' do
        platform :osx, '10.15'
        pod 'ProtonCore-TestingToolkit/UnitTests/Core', :git => proton_core_path, :tag => proton_core_version
    end
end

# iOS

target 'ProtonVPN' do
  project 'apps/ios/iOS.xcodeproj'
  platform :ios, '14.0'
  use_frameworks!

  vpn_core

  pod 'GSMessages', '~> 1.0'
  pod 'AlamofireImage', '~> 4.1'
  pod 'Alamofire', '5.4.4'
  
  reachability
  
  pod 'ProtonCore-Challenge', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-Foundations', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-Login/UsingCryptoVPN+Alamofire', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-LoginUI-V5/UsingCryptoVPN+Alamofire', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-Log', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-OpenPGP', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-DataModel', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-CoreTranslation', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-CoreTranslation-V5', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-Authentication-KeyGeneration/UsingCryptoVPN+Alamofire', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-HumanVerification-V5/Alamofire', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-Payments/UsingCryptoVPN+Alamofire', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-PaymentsUI-V5/UsingCryptoVPN+Alamofire', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-APIClient/Alamofire', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-Utilities', :git => proton_core_path, :tag => proton_core_version  
  pod 'ProtonCore-Hash', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-ForceUpgrade-V5/Alamofire', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-AccountDeletion-V5/UsingCryptoVPN+Alamofire', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-TroubleShooting', :git => proton_core_path, :tag => proton_core_version
  
  target 'OpenVPN Extension' do
    openvpn
    inherit! :search_paths
  end

  target 'Quick Connect Widget' do
    inherit! :search_paths
  end

  target 'Siri Shortcut Handler' do
    inherit! :search_paths
  end

  target 'ProtonVPNTests' do
    pod 'ProtonCore-ForceUpgrade-V5/Alamofire', :git => proton_core_path, :tag => proton_core_version
    inherit! :search_paths
  end
  
  target 'ProtonVPNUITests' do    
    platform :ios, '14.0'
    pm_automation
    pod 'ProtonCore-QuarkCommands/Alamofire', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-TestingToolkit/UITests/Login', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-TestingToolkit/UITests/HumanVerification', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-TestingToolkit/UITests/PaymentsUI', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-TestingToolkit/UITests/Core', :git => proton_core_path, :tag => proton_core_version
    pod 'SwiftOTP'
  end

end

target 'WireGuardiOS Extension' do
  project 'apps/ios/iOS.xcodeproj'
  platform :ios, '14.0'
  use_frameworks!
  
  keychain_access
end

target 'WireGuardNetworkExtensionTests' do
  project 'apps/ios/iOS.xcodeproj'
  platform :ios, '14.0'
  use_frameworks!
  
  keychain_access
end

# macOS

target 'ProtonVPN-mac' do
  project 'apps/macos/macOS.xcodeproj'

  vpn_core
  
  pod 'ProtonCore-UIFoundations-V5', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-Login/UsingCryptoVPN+Alamofire', :git => proton_core_path, :tag => proton_core_version

end

target 'ProtonVPN OpenVPN' do
  project 'apps/macos/macOS.xcodeproj'
  use_frameworks!
  openvpn
end

target 'ProtonVPN WireGuard' do
  project 'apps/macos/macOS.xcodeproj'
  use_frameworks!
  keychain_access
end

target 'ProtonVPNmacOSTests' do
  project 'apps/macos/macOS.xcodeproj'
  inherit! :search_paths
  vpn_core
end

# Other

post_install do |installer|

  # Create plist with info about used frameworks
  plugin 'cocoapods-acknowledgements'
  require 'fileutils'
  FileUtils.cp_r('Pods/Target Support Files/Pods-ProtonVPN/Pods-ProtonVPN-acknowledgements.markdown', 'ACKNOWLEDGEMENTS.md')


  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      
      # Reset deployment targets to use the one we have on the main project
      config.build_settings.delete 'MACOSX_DEPLOYMENT_TARGET'
      
    end
  end
  
  # Fix bundle signing problems started with Xcode 14: https://github.com/CocoaPods/CocoaPods/issues/11402
  ## Get main project development team id
  dev_team = ""
  project = installer.aggregate_targets[0].user_project
  project.targets.each do |target|
      target.build_configurations.each do |config|
          if dev_team.empty? and !config.build_settings['DEVELOPMENT_TEAM'].nil?
              dev_team = config.build_settings['DEVELOPMENT_TEAM']
          end
      end
  end
  
  ## Fix bundle targets' 'Signing Certificate' to 'Sign to Run Locally'
  installer.pods_project.targets.each do |target|
      if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.bundle"
          target.build_configurations.each do |config|
              config.build_settings['DEVELOPMENT_TEAM'] = dev_team
          end
      end
  end
  # End of fix
  
end
