import CopilotForXcodeKit
import Foundation
import CodableWrappers

public protocol TelemetryServiceType {
    func sendError(
        _ request: TelemetryExceptionRequest,
        workspace: WorkspaceInfo
    ) async throws
}

public protocol TelemetryServiceProvider {
    func sendError(_ request: TelemetryExceptionRequest) async throws
}

/// Represents a telemetry exception request, containing error details and additional properties.
public struct TelemetryExceptionRequest {
    /// An identifier to group or track the transaction. 
    public let transaction: String?
    /// The error stacktrace as a string.
    public let stacktrace: String?
    /// Additional telemetry properties as key-value pairs.
    public let properties: [String: String]?
    /// The target platform information (default to macOS).
    public let platform: String?
    /// A list of detailed exceptions, each with its own context.
    public let exceptionDetail: [ExceptionDetail]?
    
    public init(
        transaction: String? = nil,
        stacktrace: String? = nil,
        properties: [String: String]? = nil,
        platform: String? = nil,
        exceptionDetail: [ExceptionDetail]? = nil
    ) {
        self.transaction = transaction
        self.stacktrace = stacktrace
        self.properties = properties
        self.platform = platform
        self.exceptionDetail = exceptionDetail
    }
}

public struct ExceptionDetail: Codable {
    public let type: String?
    public let value: String?
    public let stacktrace: [StackTraceFrame]?
    
    public init(type: String? = nil, value: String? = nil, stacktrace: [StackTraceFrame]? = nil) {
        self.type = type
        self.value = value
        self.stacktrace = stacktrace
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let type = type {
            dict["type"] = type
        }
        if let value = value {
            dict["value"] = value
        }
        if let stacktrace = stacktrace {
            dict["stacktrace"] = stacktrace.map { $0.toDictionary() }
        }
        return dict
    }
}

public struct StackTraceFrame: Codable {
    public let filename: String?
    public let lineno: PositionNumberType?
    public let colno: PositionNumberType?
    public let function: String?
    public let inApp: Bool?
    
    public init(
        filename: String? = nil,
        lineno: PositionNumberType? = nil,
        colno: PositionNumberType? = nil,
        function: String? = nil,
        inApp: Bool? = nil
    ) {
        self.filename = filename
        self.lineno = lineno
        self.colno = colno
        self.function = function
        self.inApp = inApp
    }
    
    enum CodingKeys: String, CodingKey {
        case filename
        case lineno
        case colno
        case function
        case inApp = "in_app"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let filename = filename {
            dict["filename"] = filename
        }
        if let lineno = lineno {
            dict["lineno"] = lineno.toAny()
        }
        if let colno = colno {
            dict["colno"] = colno.toAny()
        }
        if let function = function {
            dict["function"] = function
        }
        if let inApp = inApp {
            dict["in_app"] = inApp
        }
        return dict
    }
}

public enum PositionNumberType: Codable {
    case string(String)
    case integer(Int)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else {
            self = .string("")
        }
    }
    
    public init(fromInt intValue: Int) {
        self = .integer(intValue)
    }
    
    public init(fromString stringValue: String) {
        self = .string(stringValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        }
    }
    
    func toAny() -> Any {
        switch self {
        case .string(let value):
            return value
        case .integer(let value):
            return value
        }
    }
}

extension Array where Element == ExceptionDetail {
    public func toDictionary() -> [[String: Any]] {
        return self.map { $0.toDictionary() }
    }
}
