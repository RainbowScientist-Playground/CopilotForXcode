import Foundation
import TelemetryServiceProvider
import UserDefaultsObserver
import Preferences

public class GitHubPanicErrorReporter {
    private static let panicEndpoint = URL(string: "https://copilot-telemetry.githubusercontent.com/telemetry")!
    private static let sessionId = UUID().uuidString
    private static let standardChannelKey = Bundle.main
        .object(forInfoDictionaryKey: "STANDARD_TELEMETRY_CHANNEL_KEY") as! String
    
    private static let userDefaultsObserver = UserDefaultsObserver(
            object: UserDefaults.shared,
            forKeyPaths: [
                UserDefaultPreferenceKeys().gitHubCopilotProxyUrl.key,
                UserDefaultPreferenceKeys().gitHubCopilotProxyUsername.key,
                UserDefaultPreferenceKeys().gitHubCopilotProxyPassword.key,
                UserDefaultPreferenceKeys().gitHubCopilotUseStrictSSL.key,
            ],
            context: nil
        )
        
        // Use static initializer to set up the observer
        private static let _initializer: Void = {
            userDefaultsObserver.onChange = {
                urlSession = configuredURLSession()
            }
        }()
        
        private static var urlSession: URLSession = {
            // Initialize urlSession after observer setup
            _ = _initializer
            return configuredURLSession()
        }()
    
    // Helper: Format current time in ISO8601 style
    private static func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSSX"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
    
    // Helper: Create failbot payload JSON string and update properties
    private static func createFailbotPayload(
        for request: TelemetryExceptionRequest,
        properties: inout [String: Any]
    ) -> String? {
        let payload: [String: Any] = [
            "context": [:],
            "app": "copilot-xcode",
            "catalog_service": "CopilotXcode",
            "release": "copilot-xcode@\(properties["common_extversion"] ?? "0.0.0")",
            "rollup_id": "auto",
            "platform": "macOS",
            "exception_detail": request.exceptionDetail?.toDictionary() ?? []
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    // Helper: Create payload with a channel input, but always using standard telemetry key.
    private static func createPayload(
        for request: TelemetryExceptionRequest,
        properties: inout [String: Any]
    ) -> [String: Any] {
        // Build and add failbot payload to properties
        if let payloadString = createFailbotPayload(for: request, properties: &properties) {
            properties["failbot_payload"] = payloadString
        }
        properties["common_vscodesessionid"] = sessionId
        properties["client_sessionid"] = sessionId
        
        let baseData: [String: Any] = [
            "ver": 2,
            "severityLevel": "Error",
            "name": "agent/error.exception",
            "properties": properties,
            "exceptions": [],
            "measurements": [:]
        ]
        
        return [
            "ver": 1,
            "time": currentTime(),
            "severityLevel": "Error",
            "name": "Microsoft.ApplicationInsights.standard.Event",
            "iKey": standardChannelKey,
            "data": [
                "baseData": baseData,
                "baseType": "ExceptionData"
            ]
        ]
    }
    
    private static func configuredURLSession() -> URLSession {
        let proxyURL = UserDefaults.shared.value(for: \.gitHubCopilotProxyUrl)
        let strictSSL = UserDefaults.shared.value(for: \.gitHubCopilotUseStrictSSL)
        
        // If no proxy, use shared session
        if proxyURL.isEmpty {
            return .shared
        }
        
        let configuration = URLSessionConfiguration.default
        
        if let url = URL(string: proxyURL) {
            var proxyConfig: [String: Any] = [:]
            let scheme = url.scheme?.lowercased()
            
            // Set proxy type based on URL scheme
            switch scheme {
            case "https":
                proxyConfig[kCFProxyTypeKey as String] = kCFProxyTypeHTTPS
                proxyConfig[kCFNetworkProxiesHTTPSEnable as String] = true
                proxyConfig[kCFNetworkProxiesHTTPSProxy as String] = url.host
                proxyConfig[kCFNetworkProxiesHTTPSPort as String] = url.port
            case "socks", "socks5":
                proxyConfig[kCFProxyTypeKey as String] = kCFProxyTypeSOCKS
                proxyConfig[kCFNetworkProxiesSOCKSEnable as String] = true
                proxyConfig[kCFNetworkProxiesSOCKSProxy as String] = url.host
                proxyConfig[kCFNetworkProxiesSOCKSPort as String] = url.port
            default:
                proxyConfig[kCFProxyTypeKey as String] = kCFProxyTypeHTTP
                proxyConfig[kCFProxyHostNameKey as String] = url.host
                proxyConfig[kCFProxyPortNumberKey as String] = url.port
            }

            // Add proxy authentication if configured
            let username = UserDefaults.shared.value(for: \.gitHubCopilotProxyUsername)
            let password = UserDefaults.shared.value(for: \.gitHubCopilotProxyPassword)
            if !username.isEmpty {
                proxyConfig[kCFProxyUsernameKey as String] = username
                proxyConfig[kCFProxyPasswordKey as String] = password
            }
            
            configuration.connectionProxyDictionary = proxyConfig
        }

        // Configure SSL verification
        if strictSSL {
            return URLSession(configuration: configuration)
        }
        
        let sessionDelegate = CustomURLSessionDelegate()

        return URLSession(
            configuration: configuration,
            delegate: sessionDelegate,
            delegateQueue: nil
        )
    }
    
    private class CustomURLSessionDelegate: NSObject, URLSessionDelegate {
        func urlSession(
            _ session: URLSession,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            // Accept all certificates when strict SSL is disabled
            guard let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        }
    }
    
    public static func report(_ request: TelemetryExceptionRequest) async {
        do {
            var properties: [String : Any] = request.properties ?? [:]
            let payload = createPayload(
                for: request,
                properties: &properties
            )

            let jsonData = try JSONSerialization.data(withJSONObject: [payload], options: [])
            var httpRequest = URLRequest(url: panicEndpoint)
            httpRequest.httpMethod = "POST"
            httpRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            httpRequest.httpBody = jsonData

            // Use the cached URLSession instead of creating a new one
            let (_, response) = try await urlSession.data(for: httpRequest)
            #if DEBUG
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            #endif
        } catch {
            #if DEBUG
            print("Fails to send to Panic Endpoint: \(error)")
            #endif
        }
    }
}
