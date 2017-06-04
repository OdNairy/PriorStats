//
//  PriorbankAPI.swift
//  Priorstats
//
//  Created by Roman Gardukevich on 6/4/17.
//  Copyright © 2017 Roman Gardukevich. All rights reserved.
//

import Foundation
import Alamofire
import PromiseKit
import SwiftyJSON
import CryptoSwift

class PriorbankAPIClient {
    
    func login(username: String, password: String) {
        let api = PriorbankAPI()
        
        var mobileTokens: PriorbankAPI.MobileTokenData?
        api.mobileToken().then { tokens in
            mobileTokens = tokens
            return api.getServerSalt(token: tokens.token, secret: tokens.secret, username: username)
        }.then { salt in
            return api.login(username: username, password: password, salt: salt, token: mobileTokens!.token, secret: mobileTokens!.secret)
        }.then { loginData in
            print(loginData)
        }
        
    }
}
extension String: Error {}

class PriorbankAPI {
    
    class func authorizationHeaderValue(_ token: String) -> String {
        return "bearer \(token)"
    }
    
    typealias MobileTokenData = (token: String, secret: String)
    func mobileToken() -> Promise<MobileTokenData> {
        return Promise { (success, failure) in
            request("https://prior.by/api3/api/Authorization/MobileToken", method: .get)
            .validate()
            .responseData(completionHandler: { (dataResponse) in
                guard let data = dataResponse.data else {
                    failure(dataResponse.error!)
                    return
                }
                let json = JSON(data: data)
                success((token: json["access_token"].stringValue, secret: json["client_secret"].stringValue))
            })
        }
        
    }
    
    typealias SaltData = String
    func getServerSalt(token: String, secret: String, username: String) -> Promise<SaltData> {
        return Promise { (success, failure) in
            
            request("https://prior.by/api3/api/Authorization/GetSalt",
                    method: .post,
                    parameters: ["lang":"RUS", "login":username],
                    encoding: JSONEncoding.default,
                    headers: ["Authorization":PriorbankAPI.authorizationHeaderValue(token), "client_id":secret])
            .validate()
            .responseData{ dataResponse in
                guard let data = dataResponse.data else {
                    failure(dataResponse.error!)
                    return
                }
                
                let json = JSON(data: data)
                guard let salt = json["result"]["salt"].string, salt == "" else {
                    failure("Salt should be \"\" but got \(json["result"]["salt"].string ?? "<no value>")")
                    return
                }
                
                success(salt)
            }
        }
    }
    
    typealias LoginData = (token: String, session: String)
    func login(username: String, password: String, salt: String, token: String, secret: String) -> Promise<LoginData> {
        return Promise(resolvers: { (success, failure) in
            let hashedPassword = (password).sha512()
            
            request("https://prior.by/api3/api/Authorization/Login",
                    method: .post,
                    parameters: ["login":username, "lang":"RUS", "password":hashedPassword],
                    encoding: JSONEncoding.default,
                    headers: ["Authorization":PriorbankAPI.authorizationHeaderValue(token), "client_id":secret, "User-Agent":"Paw/3.1 (Macintosh; OS X/10.12.5) GCDHTTPRequest"] )
            .validate()
            .responseData{ dataResponse in
                guard let data = dataResponse.data else {
                    failure(dataResponse.error!)
                    return
                }
                
                let json = JSON(data: data)
                
                let successRoot = json["result"]
                let newToken = successRoot["access_token"].stringValue
                let session = successRoot["userSession"].stringValue
                
                success((token: newToken, session: session))
            }
            
            
        })
    }
    
    
    
}
