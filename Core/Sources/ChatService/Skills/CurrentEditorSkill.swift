import ConversationServiceProvider
import Foundation
import GitHubCopilotService
import JSONRPC

public class CurrentEditorSkill: ConversationSkill {
    public static let ID = "current-editor"
    private var currentFile: FileReference
    public var id: String {
        return CurrentEditorSkill.ID
    }
    
    public init(
        currentFile: FileReference
    ) {
        self.currentFile = currentFile
    }

    public func applies(params: ConversationContextParams) -> Bool {
        return params.skillId == self.id
    }
    
    public func resolveSkill(request: ConversationContextRequest, completion: JSONRPCResponseHandler){
        let uri: String? = self.currentFile.url.absoluteString
        completion(
            AnyJSONRPCResponse(id: request.id,
                               result: JSONValue.array([
                                    JSONValue.hash(["uri" : .string(uri ?? "")]),
                                    JSONValue.null
                               ]))
        )
    }
}
