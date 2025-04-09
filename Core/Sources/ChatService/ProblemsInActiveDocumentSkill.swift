import ConversationServiceProvider
import Foundation
import GitHubCopilotService
import JSONRPC
import XcodeInspector

public class ProblemsInActiveDocumentSkill: ConversationSkill {
    public static let ID = "problems-in-active-document"
    public var id: String {
        return ProblemsInActiveDocumentSkill.ID
    }

    public init() {
    }

    public func applies(params: ConversationContextParams) -> Bool {
        return params.skillId == self.id
    }

    public func resolveSkill(request: ConversationContextRequest, completion: @escaping (AnyJSONRPCResponse) -> Void) {
        Task {
            let editor = await XcodeInspector.shared.getFocusedEditorContent()
            let result: JSONValue = JSONValue.hash([
                "uri": JSONValue.string(editor?.documentURL.absoluteString ?? ""),
                "problems": JSONValue.array(editor?.editorContent?.lineAnnotations.map { annotation in
                    JSONValue.hash([
                        "message": JSONValue.string(annotation.message),
                        "range": JSONValue.hash([
                            "start": JSONValue.hash([
                                "line": JSONValue.number(Double(annotation.line)),
                                "character": JSONValue.number(0)
                                ]),
                            "end": JSONValue.hash([
                                "line": JSONValue.number(Double(annotation.line)),
                                "character": JSONValue.number(0)
                                ])
                            ])
                        ])
                } ?? [])
            ])

            completion(
                AnyJSONRPCResponse(id: request.id,
                                   result: JSONValue.array([
                                        result,
                                        JSONValue.null
                                   ]))
            )
        }
    }
}

