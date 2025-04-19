import Logger
import Foundation
import TelemetryService

public class TelemetryLogger: TelemetryLoggerProvider {
    public func sendError(
        error: any Error,
        category: String,
        file: StaticString,
        line: UInt,
        function: StaticString,
        callStackSymbols: [String]
    ) {
        TelemetryService.shared.sendError(
            error,
            category: category,
            file: file,
            line: line,
            function: function,
            from: callStackSymbols
        )
    }
    
    public func sendError(
        message: String,
        category: String,
        file: StaticString,
        line: UInt,
        function: StaticString,
        callStackSymbols: [String]
    ) {
        TelemetryService.shared
            .sendError(
                message,
                category: category,
                file: file,
                line: line,
                function: function,
                from: callStackSymbols
            )
    }
}
