//
//  File.swift
//  
//
//  Created by JuDH on 5/14/24.
//

import Foundation
import AWSS3

public enum CredentialsProviderHolder {
    var credentialsProvider: AWSCredentialsProvider {
        switch self {
        case let .accessKeyProvider(accessKey, secretKey):
            return AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        case let .identityPoolProvider(identityPoolId, region):
            return AWSCognitoCredentialsProvider(regionType: region, identityPoolId: identityPoolId)
        }
    }

    case accessKeyProvider(accessKey: String, secretKey: String)
    case identityPoolProvider(identityPoolId: String, region: AWSRegionType)
}

