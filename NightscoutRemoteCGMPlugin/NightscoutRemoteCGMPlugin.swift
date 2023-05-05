//
//  NightscoutRemoteCGMPlugin.swift
//  NightscoutRemoteCGMPlugin
//
//  Created by Bill Gestrich on 8/18/21.
//  Copyright © 2021 Ivan Valkou. All rights reserved.
//

import os.log
import LoopKitUI
import NightscoutRemoteCGM

class NightscoutRemoteCGMPlugin: NSObject, CGMManagerUIPlugin {
    private let log = OSLog(category: "NightscoutRemoteCGMPlugin")
    
    public var cgmManagerType: CGMManagerUI.Type? {
        NightscoutRemoteCGM.self
    }

    override init() {
        super.init()
        log.default("Instantiated")
    }
}
