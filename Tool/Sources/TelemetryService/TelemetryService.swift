import Foundation
import SystemUtils
import TelemetryServiceProvider
import BuiltinExtension
import GitHubCopilotService

public protocol WrappedTelemetryServiceType {
    func sendError(
        _ error: Error?,
        transaction: String?,
        additionalProperties: [String: String]?,
        category: String,
        file: StaticString,
        line: UInt,
        function: StaticString,
        from symbols: [String]
    )
    
    func sendError(
        _ message: String,
        transaction: String?,
        additionalProperties: [String: String]?,
        category: String,
        file: StaticString,
        line: UInt,
        function: StaticString,
        from symbols: [String]
    )
}

public actor TelemetryService: WrappedTelemetryServiceType {
    private let telemetryProvider: TelemetryServiceProvider?
    private var commonProperties: [String: String] = [:]
    private let telemetryCleaner: TelemetryCleaner = TelemetryCleaner(cleanupPatterns: [])

    public static var shared: TelemetryService = TelemetryService.service()
    
    init(
        provider: any TelemetryServiceProvider
    ) {
        telemetryProvider = provider
        self.commonProperties = [
            "common_extname": "copilot-xcode",
            "common_extversion": SystemUtils.editorPluginVersionString,
            "common_os": "darwin",
            "common_platformversion": SystemUtils.osVersion,
            "common_uikind": "desktop",
            "common_vscodemachineid": SystemUtils.machineId,
            "client_machineid": SystemUtils.machineId,
            "editor_version": SystemUtils.editorVersionString,
            "editor_plugin_version": "copilot-xcode/\(SystemUtils.editorPluginVersionString)",
            "copilot_build": SystemUtils.build,
            "copilot_buildType": SystemUtils.buildType
        ]
    }
    
    public static func service() -> TelemetryService {
        let provider = BuiltinExtensionTelemetryServiceProvider(
            extension: GitHubCopilotExtension.self
        )
        return TelemetryService(provider: provider)
    }
    
    enum TelemetryServiceError: Error {
        case providerNotFound
    }

    private enum ErrorSource {
        case message(String)
        case error(Error?)
    }
    
    /// Sends an error with the given parameters
    public nonisolated func sendError(
        _ error: Error?,
        transaction: String? = nil,
        additionalProperties: [String: String]? = nil,
        category: String = "",
        file: StaticString,
        line: UInt,
        function: StaticString,
        from symbols: [String]
    ) {
        Task.detached(priority: .background) {
            await self.sendErrorInternal(
                .error(error),
                transaction: transaction,
                additionalProperties: additionalProperties,
                category: category,
                file: file,
                line: line,
                function: function,
                from: symbols
            )
        }
    }
    
    /// Sends an error message with the given parameters
    public nonisolated func sendError(
        _ message: String,
        transaction: String? = nil,
        additionalProperties: [String: String]? = nil,
        category: String = "",
        file: StaticString,
        line: UInt,
        function: StaticString,
        from symbols: [String]
    ) {
        Task.detached(priority: .background) {
            await self.sendErrorInternal(
                .message(message),
                transaction: transaction,
                additionalProperties: additionalProperties,
                category: category,
                file: file,
                line: line,
                function: function,
                from: symbols
            )
        }
    }
    
    /// Internal implementation for sending errors
    private func sendErrorInternal(
        _ source: ErrorSource,
        transaction: String? = nil,
        additionalProperties: [String: String]? = nil,
        category: String = "",
        file: StaticString,
        line: UInt,
        function: StaticString,
        from symbols: [String]
    ) async {
        var props = commonProperties
        additionalProperties?.forEach { props[$0.key] = $0.value }
        let fileName: String = telemetryCleaner.redact(String(describing: file)) ?? ""
        let request = createTelemetryExceptionRequest(
            errorSource: source,
            transaction: transaction,
            additionalProperties: props,
            category: category,
            file: fileName,
            line: line,
            function: function,
            symbols: symbols
        )
        
        do {
            if let provider = telemetryProvider {
                try await provider.sendError(request)
            } else {
                throw TelemetryServiceError.providerNotFound
            }
        } catch {
            await GitHubPanicErrorReporter.report(request)
        }
    }
    
    /// Creates a telemetry exception request from the given parameters
    private func createTelemetryExceptionRequest(
        errorSource: ErrorSource,
        transaction: String?,
        additionalProperties: [String: String],
        category: String,
        file: String,
        line: UInt,
        function: StaticString,
        symbols: [String]
    ) -> TelemetryExceptionRequest {
        let stacktrace: String? = switch errorSource {
        case .message(let message):
            message
        case .error(let error):
            error?.localizedDescription
        }
        
        let exceptionDetails = convertErrorToExceptionDetails(
            errorSource,
            category: category,
            file: file,
            line: line,
            function: function,
            from: symbols
        )
        
        return TelemetryExceptionRequest(
            transaction: transaction,
            stacktrace: telemetryCleaner.redact(stacktrace),
            properties: additionalProperties,
            platform: "macOS",
            exceptionDetail: exceptionDetails
        )
    }

    /// Converts error source to exception details array
    private func convertErrorToExceptionDetails(
        _ errorSource: ErrorSource,
        category: String,
        file: String,
        line: UInt,
        function: StaticString,
        from symbols: [String]
    ) -> [ExceptionDetail] {
        let (errorType, errorValue) = extractErrorInfo(from: errorSource, category: category)
        let stackFrames = createStackFrames(
            errorSource: errorSource,
            file: file,
            line: line,
            function: function,
            symbols: symbols
        )
        
        return [
            ExceptionDetail(
                type: errorType,
                value: telemetryCleaner.redact(errorValue),
                stacktrace: stackFrames
            )
        ]
    }

    /// Extracts error type and value from error source
    private func extractErrorInfo(from errorSource: ErrorSource, category: String) -> (type: String, value: String) {
        switch errorSource {
        case .message(let message):
            let type = "ErrorMessage \(category)"
            return (type, message)
            
        case .error(let error):
            guard let error = error else {
                let type = "UnknownError \(category)"
                return (type, "Unknown error occurred")
            }
            
            var typePrefix = String(describing: type(of: error))
            if typePrefix == "NSError" {
                let nsError = error as NSError
                typePrefix += ":\(nsError.domain):\(nsError.code)"
            }
            
            let type = typePrefix + " \(category)"
            return (type, error.localizedDescription)
        }
    }

    /// Creates stack trace frames from error information
    private func createStackFrames(
        errorSource: ErrorSource,
        file: String,
        line: UInt,
        function: StaticString,
        symbols: [String]
    ) -> [StackTraceFrame] {
        let callSiteFrame = StackTraceFrame(
            filename: file,
            lineno: .integer(Int(line)),
            colno: nil,
            function: String(describing: function),
            inApp: true
        )
        
        switch errorSource {
        case .message:
            return [callSiteFrame]
            
        case .error:
            var frames = parseStackFrames(from: symbols)
            frames.insert(callSiteFrame, at: 0)
            return frames
        }
    }

    /// Parses call stack symbols into stack trace frames
    private func parseStackFrames(from symbols: [String]) -> [StackTraceFrame] {
        symbols.map { symbol -> StackTraceFrame? in
            let pattern = #"^(\d+)\s+(.+?)\s+(0x[0-9a-fA-F]+)\s+(.+?)\s+\+\s+(\d+)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            guard let match = regex.firstMatch(in: symbol, range: NSRange(symbol.startIndex..., in: symbol)) else { return nil }
            
            let components = (1..<match.numberOfRanges).map { i -> String in
                if let range = Range(match.range(at: i), in: symbol) {
                    return String(symbol[range])
                }
                return ""
            }
            
            guard components.count == 5,
                  let offset = Int(components[4]) else { return nil }
            
            let module = components[1]
            let parsedSymbol = parseDemangledSymbol(swift_demangle(components[3]))
            
            return StackTraceFrame(
                filename: parsedSymbol?.module ?? module,
                lineno: .integer(offset),
                colno: nil,
                function: parsedSymbol?.function ?? components[3],
                inApp: module.contains("GitHub Copilot for Xcode Extension")
            )
        }.compactMap { $0 }
    }
    
    /// Demangles Swift symbol names using the Swift runtime
    typealias Swift_Demangle = @convention(c) (_ mangledName: UnsafePointer<UInt8>?,
                                               _ mangledNameLength: Int,
                                               _ outputBuffer: UnsafeMutablePointer<UInt8>?,
                                               _ outputBufferSize: UnsafeMutablePointer<Int>?,
                                               _ flags: UInt32) -> UnsafeMutablePointer<Int8>?

    func swift_demangle(_ mangled: String) -> String {
        let RTLD_DEFAULT = dlopen(nil, RTLD_NOW)
        if let sym = dlsym(RTLD_DEFAULT, "swift_demangle") {
            let f = unsafeBitCast(sym, to: Swift_Demangle.self)
            if let cString = f(mangled, mangled.count, nil, nil, 0) {
                defer { cString.deallocate() }
                return String(cString: cString)
            }
        }
        return ""
    }
    
    /// Parses demangled symbol into module and function components
    func parseDemangledSymbol(_ demangled: String) -> (module: String, function: String)? {
        let regex = try! NSRegularExpression(
            pattern: #"^\((\d+)\)\s*(.*?)\s*for\s*([^\s]+(?: [^\s]+)*?)\s*((?:async)?)\s*((?:throws)?)\s*(?:->\s*(.*))?$"#,
            options: [.anchorsMatchLines]
        )
        guard let match = regex.firstMatch(
            in: demangled, options: [],
            range: NSRange(location: 0, length: demangled.utf16.count)
        ) else {
            return nil
        }
        let functionName = (demangled as NSString).substring(with: match.range(at: 3))
        return (module: functionName, function: demangled)
    }
}
