//
//  Logger+Adapters.swift
//  GameOfThronesInfo
//
//  Created by Vladimir Martemianov on 16.4.25..
//

// Static storage for adapters
extension Logger {
    private static var adapters: [LogAdapter] = []
    
    /// Adds a log adapter
    /// - Parameter adapter: Adapter conforming to LogAdapter
    public static func addAdapter(_ adapter: LogAdapter) {
        adapters.append(adapter)
    }
    
    /// Removes all log adapters
    public static func removeAllAdapters() {
        adapters.removeAll()
    }
    
    /// Notifies all registered adapters of a log event
    /// - Parameters:
    ///   - message: Log message
    ///   - level: Log level
    ///   - subsystem: Subsystem
    ///   - category: Category
    ///   - file: File
    ///   - function: Function
    ///   - line: Line
    static func notifyAdapters(message: String, level: Level, subsystem: String, category: String, file: String, function: String, line: Int) {
        for adapter in adapters {
            adapter.log(message: message, level: level, subsystem: subsystem, category: category, file: file, function: function, line: line)
        }
    }
}
