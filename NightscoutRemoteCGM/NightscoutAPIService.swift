//
//  NightscoutAPIService.swift
//  NightscoutRemoteCGM
//
//  Created by Ivan Valkou on 10.10.2019.
//  Copyright © 2019 Ivan Valkou. All rights reserved.
//

import LoopKit
import Combine
import os.log

public class NightscoutAPIService: ServiceAuthentication {

    private let log = OSLog(subsystem: "com.loopkit.NightscoutRemoteCGM", category: "NightscoutAPIService")
    private(set) var client: NightscoutFetcher?
    private var requestReceiver: Cancellable?
    
    public init(url: URL?, apiSecret: String?) {
        credentialValues = [url?.absoluteString, apiSecret]

        // An API secret is only needed for sites that require authentication to read.
        // A URL alone is enough to read from a Nightscout site that is open for reading.
        if let url = url {
            isAuthorized = true
            client = NightscoutFetcher(url: url, apiSecret: apiSecret ?? "")
        }
    }
    
    public var url: URL? {
        guard let urlString = credentialValues[0] else {
            return nil
        }
        return URL(string: urlString)
    }
    
    public var apiSecret: String? {
        guard let apiSecret = credentialValues[1] else {
            return nil
        }
        return apiSecret
    }
    
    public func checkServiceStatus(_ completion: @escaping (Result<Void, NightScoutAPIServiceError>) -> Void) {
        
        let log = self.log

        guard let url = url else {
            os_log("Verification failed: no URL configured", log: log, type: .error)
            completion(.failure(.missingURL))
            return
        }

        os_log("Verifying Nightscout CGM at %{public}@ (API Secret: %{public}@)", log: log, type: .default, url.absoluteString, (apiSecret?.isEmpty == false) ? "provided" : "none")

        //Not using client property in case called by ServiceAuthentication framework
        //as it only gets set after first validation
        let client = NightscoutFetcher(url: url, apiSecret: apiSecret ?? "")
        requestReceiver?.cancel()

        client.fetchRecent() { result in
            switch result {
            case .success(let entries):
                if entries.isEmpty {
                    os_log("Verification failed: connected, but no recent glucose values were returned", log: log, type: .error)
                    completion(.failure(NightScoutAPIServiceError.emptyGlucose))
                } else {
                    os_log("Verification succeeded: %{public}@ recent glucose entries", log: log, type: .default, String(entries.count))
                    completion(.success(()))
                }
            case let .failure(error):
                os_log("Verification failed: %{public}@", log: log, type: .error, String(describing: error))
                completion(.failure(.apiError(error)))
            }
        }

        self.client = client
    }
    
    
    // MARK: - ServiceAuthentication conformance
    
    public let title = LocalizedString("Nightscout Remote CGM", comment: "The title of the Nightscout service")
    public var credentialValues: [String?]
    public var isAuthorized = false
    
    public func verify(_ completion: @escaping (Bool, Error?) -> Void) {
        checkServiceStatus { result in
            switch result {
            case .success():
                completion(true, nil)
            case .failure(let err):
                completion(false, err)
            }
        }
    }

    public func reset() {
        isAuthorized = false
        client = nil
        requestReceiver?.cancel()
    }

    
    public enum NightScoutAPIServiceError: LocalizedError {
        case emptyGlucose
        case missingURL
        case apiError(Error)
        
        public var errorDescription: String? {
            switch self {
            case .emptyGlucose:
                return "No recent glucose values available."
            case .missingURL:
                return "Service is not setup."
            case .apiError(let error):
                return error.localizedDescription
            }
        }
    }
}

extension KeychainManager {
    private enum Config {
        static let nightscoutCgmLabel = "NightscoutCGM"
    }

    func setNightscoutCgmCredentials(_ url: URL?, apiSecret: String?) {
        do {
            let credentials: InternetCredentials?

            if let url = url {
                credentials = InternetCredentials(username: Config.nightscoutCgmLabel, password: apiSecret ?? "", url: url)
            } else {
                credentials = nil
            }

            try replaceInternetCredentials(credentials, forAccount: Config.nightscoutCgmLabel)
        } catch {}
    }

    func getNightscoutCgmURL() -> URL? {
        do {
            let credentials = try getInternetCredentials(account: Config.nightscoutCgmLabel)
            return credentials.url
        } catch {
            return nil
        }
    }
    
    func getNightscoutAPISecret() -> String? {
        do {
            let credentials = try getInternetCredentials(account: Config.nightscoutCgmLabel)
            return credentials.password
        } catch {
            return nil
        }
    }
}

extension NightscoutAPIService {
    public convenience init(keychainManager: KeychainManager = KeychainManager()) {
        self.init(url: keychainManager.getNightscoutCgmURL(), apiSecret: keychainManager.getNightscoutAPISecret())
    }
}
