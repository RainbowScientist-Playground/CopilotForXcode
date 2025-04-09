public protocol TelemetryLoggerProvider {
    func sendError(
        message: String,
        category: String,
        file: StaticString,
        line: UInt,
        function: StaticString,
        callStackSymbols: [String]
    )
    func sendError(
        error: Error,
        category: String,
        file: StaticString,
        line: UInt,
        function: StaticString,
        callStackSymbols: [String]
    )
}
