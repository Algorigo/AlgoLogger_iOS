//
//  DataDogLogDelegate.swift
//  AlgoLogger
//
//  Created by Rouddy on 3/11/25.
//

import DatadogCore
import DatadogLogs
import DatadogInternal


class DataDogLogDelegate: LogDelegate {
    
    fileprivate var datadogLogger = [String: LoggerProtocol]()
    fileprivate let remoteLogThreshold: LogLevel
    fileprivate let networkInfoEnabled: Bool
    fileprivate let consoleLogFormat: Logger.Configuration.ConsoleLogFormat
    fileprivate let remoteSampleRate: Float
    fileprivate let bundleWithRumEnabled: Bool
    fileprivate let bundleWithTraceEnabled: Bool
    fileprivate var tagMap = [String: String]()
    fileprivate var attributeMap = [String: String]()
    
    init(clientToken: String, env: String, service: String, verbosityLevel: CoreLoggerLevel = .debug, remoteLogThreshold: LogLevel = .info, networkInfoEnabled: Bool = true, consoleLogFormat: Logger.Configuration.ConsoleLogFormat = .short, remoteSampleRate: Float = SampleRate.maxSampleRate, bundleWithRumEnabled: Bool = true, bundleWithTraceEnabled: Bool = true) {
        let configuration = Datadog.Configuration(
            clientToken: clientToken,
            env: env,
            service: service
        )
        Datadog.initialize(with: configuration, trackingConsent: .granted)
        Logs.enable()
        Datadog.verbosityLevel = verbosityLevel
        
        self.remoteLogThreshold = remoteLogThreshold
        self.networkInfoEnabled = networkInfoEnabled
        self.consoleLogFormat = consoleLogFormat
        self.remoteSampleRate = remoteSampleRate
        self.bundleWithRumEnabled = bundleWithRumEnabled
        self.bundleWithTraceEnabled = bundleWithTraceEnabled
    }
    
    func initTag(_ tag: Tag) {
        if Datadog.isInitialized() && datadogLogger.keys.contains(tag.name) {
            let logger = Logger.create(with: Logger.Configuration(
                name: tag.name,
                networkInfoEnabled: networkInfoEnabled,
                bundleWithRumEnabled: bundleWithRumEnabled,
                bundleWithTraceEnabled: bundleWithTraceEnabled,
                remoteSampleRate: remoteSampleRate,
                remoteLogThreshold: remoteLogThreshold,
                consoleLogFormat: consoleLogFormat
            ))
            tagMap.forEach { (key, value) in
                logger.addTag(withKey: key, value: value)
            }
            attributeMap.forEach { (key, value) in
                logger.addAttribute(forKey: key, value: value)
            }
            datadogLogger[tag.name] = logger
        }
    }
    
    func addDDTag(_ key: String, value: String) {
        tagMap[key] = value
    }
    
    func removeDDTag(_ key: String) {
        tagMap.removeValue(forKey: key)
    }
    
    func addAttribute(_ key: String, value: String) {
        attributeMap[key] = value
    }
    
    func removeAttribute(_ key: String) {
        attributeMap.removeValue(forKey: key)
    }
    
    func getLogger(_ tag: Tag) -> LoggerProtocol? {
        return datadogLogger[tag.name]
    }
}
