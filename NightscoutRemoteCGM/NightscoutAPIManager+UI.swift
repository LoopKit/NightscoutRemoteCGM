//
//  NightscoutAPIManager+UI.swift
//  NightscoutRemoteCGM
//
//  Created by Ivan Valkou on 21.10.2019.
//  Copyright © 2019 Ivan Valkou. All rights reserved.
//

import LoopKitUI
import LoopKit

extension NightscoutRemoteCGM: CGMManagerUI {

    
    // TODO Placeholder.
    public static var onboardingImage: UIImage? {
        return UIImage(named: "nightscout", in: Bundle(for: NightscoutAPISettingsViewController.self), compatibleWith: nil)!
    }
    
    public static func setupViewController(bluetoothProvider: LoopKit.BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopKitUI.LoopUIColorPalette, allowDebugFeatures: Bool, prefersToSkipUserInteraction: Bool) -> LoopKitUI.SetupUIResult<LoopKitUI.CGMManagerViewController, LoopKitUI.CGMManagerUI>
    {
        return .userInteractionRequired(NightscoutAPISetupViewController())
    }
    
    public func settingsViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> CGMManagerViewController
    {
        let settings = NightscoutAPISettingsViewController(cgmManager: self, displayGlucosePreference: displayGlucosePreference)
        let nav = CGMManagerSettingsNavigationViewController(rootViewController: settings)
        return nav
    }
    
    public var smallImage: UIImage? {
        return UIImage(named: "nightscout", in: Bundle(for: NightscoutAPISettingsViewController.self), compatibleWith: nil)!
    }
    
    // TODO Placeholder.
    public var cgmStatusHighlight: DeviceStatusHighlight? {
        return nil
    }

    // TODO Placeholder.
    public var cgmStatusBadge: DeviceStatusBadge? {
        return nil
    }

    // TODO Placeholder.
    public var cgmLifecycleProgress: DeviceLifecycleProgress? {
        return nil
    }
}
