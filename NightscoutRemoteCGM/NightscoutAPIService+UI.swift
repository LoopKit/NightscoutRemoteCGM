//
//  NightscoutAPIService+UI.swift
//  NightscoutRemoteCGM
//
//  Created by Ivan Valkou on 21.10.2019.
//  Copyright © 2019 Ivan Valkou. All rights reserved.
//

import LoopKitUI

extension NightscoutAPIService: ServiceAuthenticationUI {
    public var credentialFormFields: [ServiceCredential] {
        [
            ServiceCredential(
                title: LocalizedString("URL", comment: "The title of the Nightscout API server URL credential"),
                isSecret: false,
                keyboardType: .URL
            ),
            ServiceCredential(
                title: LocalizedString("API Secret (optional)", comment: "The title of the Nightscout API secret credential"),
                isSecret: true,
                keyboardType: .default
            )
        ]
    }

    public var credentialFormFieldHelperMessage: String? {
        return LocalizedString("An API Secret is only needed for Nightscout sites that require authentication to read. Leave it blank for sites that are open for reading.", comment: "Helper message explaining that the Nightscout API secret is optional for sites open for reading")
    }
}
