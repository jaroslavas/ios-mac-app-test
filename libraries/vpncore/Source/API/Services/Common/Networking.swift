//
//  Networking.swift
//  Core
//
//  Created by Igor Kulman on 23.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_Networking
import ProtonCore_Services

public typealias SuccessCallback = (() -> Void)
public typealias GenericCallback<T> = ((T) -> Void)
public typealias JSONCallback = GenericCallback<JSONDictionary>
public typealias StringCallback = GenericCallback<String>
public typealias ErrorCallback = GenericCallback<Error>

public protocol NetworkingFactory {
    func makeNetworking() -> Networking
}

public protocol Networking: AnyObject {
    func request(_ route: Request, completion: @escaping (_ result: Result<JSONDictionary, Error>) -> Void)
    func request(_ route: Request, completion: @escaping (_ result: Result<(), Error>) -> Void)
    func request(_ route: Request, completion: @escaping (_ result: Result<String, Error>) -> Void)
}

public final class CoreNetworking: Networking {
    private var apiService: APIService

    public init() {
        apiService = PMAPIService(doh: ApiConstants.doh)
        apiService.authDelegate = self
        apiService.serviceDelegate = self
    }

    public func request(_ route: Request, completion: @escaping (_ result: Result<JSONDictionary, Error>) -> Void) {
        let url = "\(route.method.toString().uppercased()): \(apiService.doh.getHostUrl())/\(route.path)".cleanedForLog
        PMLog.D("Request started: \(url)", level: .debug)

        apiService.request(method: route.method, path: route.path, parameters: route.parameters, headers: route.header, authenticated: route.isAuth, autoRetry: route.autoRetry, customAuthCredential: route.authCredential) { (task, data, error) in

            PMLog.D("Request finished: \(url) (\(error?.localizedDescription ?? ""))")

            if let error = error {
                completion(.failure(error))
                return
            }

            if let data = data {
                var result = [String: AnyObject]()
                for (key, value) in data {
                    if let v = value as? AnyObject {
                        result[key] = v
                    }
                }
                completion(.success(result))
                return
            }

            completion(.success([:]))
        }
    }

    public func request(_ route: Request, completion: @escaping (_ result: Result<(), Error>) -> Void) {
        let url = "\(route.method.toString().uppercased()): \(apiService.doh.getHostUrl())/\(route.path)".cleanedForLog
        PMLog.D("Request started: \(url)", level: .debug)

        apiService.request(method: route.method, path: route.path, parameters: route.parameters, headers: route.header, authenticated: route.isAuth, autoRetry: route.autoRetry, customAuthCredential: route.authCredential) { (task, data, error) in

            PMLog.D("Request finished: \(url) (\(error?.localizedDescription ?? ""))")

            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }
    }

    public func request(_ route: Request, completion: @escaping (_ result: Result<String, Error>) -> Void) {
        fatalError()
    }
}

extension CoreNetworking: AuthDelegate {
    public func getToken(bySessionUID uid: String) -> AuthCredential? {
        guard let credentials = AuthKeychain.fetch() else {
            return nil
        }
        return ProtonCore_Networking.AuthCredential(sessionID: credentials.sessionId, accessToken: credentials.accessToken, refreshToken: credentials.refreshToken, expiration: credentials.expiration, privateKey: nil, passwordKeySalt: nil)
    }

    public func onLogout(sessionUID uid: String) {

    }

    public func onUpdate(auth: Credential) {
        guard let credentials = AuthKeychain.fetch() else {
            return
        }
        try? AuthKeychain.store(AuthCredentials(version: credentials.VERSION, username: credentials.username, accessToken: auth.accessToken, refreshToken: auth.refreshToken, sessionId: credentials.sessionId, userId: credentials.userId, expiration: auth.expiration, scopes: auth.scope.compactMap({ AuthCredentials.Scope($0) })))
    }

    public func onRefresh(bySessionUID uid: String, complete: @escaping AuthRefreshComplete) {

    }

    public func onForceUpgrade() {

    }
}

extension CoreNetworking: APIServiceDelegate {
    public var locale: String {
        return NSLocale.current.languageCode ?? "en_US"
    }
    public var appVersion: String {
        return ApiConstants.appVersion
    }
    public var userAgent: String? {
        return ApiConstants.userAgent
    }
    public func onUpdate(serverTime: Int64) {
        // CryptoUpdateTime(serverTime)
    }
    public func isReachable() -> Bool {
        return true
    }
    public func onDohTroubleshot() { }
}
