//
//  LogAdapterProtocol.swift
//  LoggerKit
//
//  Created by Vladimir Martemianov on 16.4.25..
//

// MARK: - Extension for additional logging adapters

/// Log adapter protocol
public protocol LogAdapter {
    func log(message: String, level: Level, subsystem: String, category: String, file: String, function: String, line: Int)
}
