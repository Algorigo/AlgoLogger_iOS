//
//  RotatingFileDestination+registerS3Uploader.swift
//  AlgoLogger
//
//  Created by Rouddy on 3/18/25.
//

import AlgoLogger
import RxSwift
import AWSS3

class AwsNotConfigured: Error {
    
}

extension RotatingFileDestination {
    
    public func registerS3Uploader(
        credentialsProviderHolder: CredentialsProviderHolder,
        region: AWSRegionType,
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
        region: AWSRegionType,
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
        region: AWSRegionType
    ) -> Single<AWSS3> {
        return Single<AWSS3>.create(subscribe: { observer in
            let key = "S3_\(credentialsProviderHolder.credentialsProvider)_\(region)"
            let configuration = AWSServiceConfiguration(region: region, credentialsProvider: credentialsProviderHolder.credentialsProvider)!
            AWSS3.register(with: configuration, forKey: key)
            observer(.success(AWSS3.s3(forKey: key)))
            return Disposables.create()
        })
    }
}

extension AWSS3 {
    func putObjectCompletable(logFile: RatatingLogFile, bucketName: String, keyDelegate: @escaping (RatatingLogFile) -> String) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(RotatingFileDestinationError.destinationReleased))
                return Disposables.create()
            }
            
            if FileManager.default.fileExists(atPath: logFile.path),
               let data = try? Data(contentsOf: URL(fileURLWithPath: logFile.path)) {
                if let request = AWSS3PutObjectRequest() {
                    request.bucket = bucketName
                    request.key = keyDelegate(logFile)
                    request.body = data
                    request.contentLength = NSNumber(value: UInt64(data.count))
                    request.contentType = "text/plain"
                    self.putObject(request) { output, error in
                        if let error = error {
                            observer(.error(error))
                        } else {
                            observer(.completed)
                        }
                    }
                } else {
                    observer(.error(AwsNotConfigured()))
                }
            } else {
                observer(.completed)
            }
            return Disposables.create()
        }
    }
}
