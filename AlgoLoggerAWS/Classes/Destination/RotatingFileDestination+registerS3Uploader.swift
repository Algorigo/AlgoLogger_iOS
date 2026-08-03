//
//  RotatingFileDestination+registerS3Uploader.swift
//  AlgoLogger
//
//  Created by Rouddy on 3/18/25.
//

import AlgoLogger
import RxSwift
import AWSS3
import AWSClientRuntime
import Foundation
import Smithy
import SmithyStreams
import AWSSDKIdentity

enum RotatingFileError: Error {
    case inputStreamError
}

extension RotatingFileDestination {
    
    public func registerS3Uploader(
        credentialsProviderHolder: CredentialsProviderHolder,
        region: AWSRegion,
        bucketName: String,
        keyDelegate: @escaping (RatatingLogFile) -> String
    ) {
        registerUploader(completable: RotatingFileDestination.getS3Single(credentialsProviderHolder: credentialsProviderHolder, region: region)
            .asObservable()
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .flatMap({ [weak self] awsS3 in
                guard let self = self else { return Observable<Never>.error(RotatingFileDestinationError.destinationReleased) }
                
                return self.getLogFileObservable()
                    .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                    .filter({ logFile in
                        logFile.postfix.isEmpty
                    })
                    .concatMap { logFile in
                        return awsS3
                            .putObjectCompletable(logFile: logFile, bucketName: bucketName, keyDelegate: keyDelegate)
                            .retry(when: { errorObservable in
                                errorObservable
                                    .delay(RxTimeInterval.seconds(60), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                            })
                            .do(onCompleted: {
                                _ = RotatingFileDestination.setPostfix(logFile: logFile, postfix: "s3")
                            })
                    }
            })
            .ignoreElements()
            .asCompletable())
    }
    
    public func registerS3Uploader(
        credentialsProviderHolder: CredentialsProviderHolder,
        region: AWSRegion,
        bucketName: String,
        dateFormatter: DateFormatter
    ) {
        registerUploader(completable: RotatingFileDestination.getS3Single(credentialsProviderHolder: credentialsProviderHolder, region: region)
            .asObservable()
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .flatMap({ [weak self] awsS3 in
                guard let self = self else { return Observable<Never>.error(RotatingFileDestinationError.destinationReleased) }
                
                return self.getLogFileObservable()
                    .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                    .filter({ logFile in
                        logFile.postfix.isEmpty
                    })
                    .concatMap { logFile in
                        return awsS3
                            .putObjectCompletable(logFile: logFile, bucketName: bucketName) { logFile in
                                dateFormatter.string(from: logFile.rotatedDate)
                            }
                            .retry(when: { errorObservable in
                                errorObservable
                                    .delay(RxTimeInterval.seconds(60), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                            })
                            .do(onCompleted: {
                                _ = RotatingFileDestination.setPostfix(logFile: logFile, postfix: "s3")
                            })
                    }
            })
            .ignoreElements()
            .asCompletable())
    }
    
    fileprivate static func getS3Single(
        credentialsProviderHolder: CredentialsProviderHolder,
        region: AWSRegion
    ) -> Single<S3Client> {
        return Single<S3Client>.create(subscribe: { observer in
            do {
                let configuration: S3Client.Configuration
                switch credentialsProviderHolder {
                case .accessKeyProvider(let accessKey, let secretKey):
                    let credential = AWSCredentialIdentity(accessKey: accessKey, secret: secretKey)
                    let resolver = StaticAWSCredentialIdentityResolver(credential)
                    configuration = try S3Client.Configuration(awsCredentialIdentityResolver: resolver, region: region.rawValue)
                case .identityPoolProvider(let resolver):
                    configuration = try S3Client.Configuration(region: region.rawValue, authSchemeResolver: resolver)
                }
                let client = S3Client(config: configuration)
                observer(.success(client))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        })
    }
}

extension S3Client {
    func putObjectCompletable(logFile: RatatingLogFile, bucketName: String, keyDelegate: @escaping (RatatingLogFile) -> String) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(RotatingFileDestinationError.destinationReleased))
                return Disposables.create()
            }
            
            if FileManager.default.fileExists(atPath: logFile.path) {
                let fileURL = URL(fileURLWithPath: logFile.path)
                let fileName = fileURL.lastPathComponent
                do {
                    let fileHandle = try FileHandle(forReadingFrom: fileURL)
                    let byteStream = ByteStream.stream(FileStream(fileHandle: fileHandle))
                    
                    let input = PutObjectInput(body: byteStream, bucket: bucketName, key: keyDelegate(logFile))
                    Task {
                        let output = try await self.putObject(input: input)
                        observer(.completed)
                    }
                } catch {
                    observer(.error(error))
                }
            } else {
                observer(.completed)
            }
            return Disposables.create()
        }
    }
}
