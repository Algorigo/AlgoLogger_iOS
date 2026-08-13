//
//  File.swift
//  
//
//  Created by JuDH on 5/14/24.
//

import Foundation
import AWSCognitoIdentityProvider

public enum CredentialsProviderHolder {
    case accessKeyProvider(accessKey: String, secretKey: String)
    case identityPoolProvider(resolver: CognitoIdentityProviderAuthSchemeResolver)
}

