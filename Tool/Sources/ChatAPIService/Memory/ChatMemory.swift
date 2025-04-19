import Foundation

public protocol ChatMemory {
    /// The message history.
    var history: [ChatMessage] { get async }
    /// Update the message history.
    func mutateHistory(_ update: (inout [ChatMessage]) -> Void) async
}

public extension ChatMemory {
    /// Append a message to the history.
    func appendMessage(_ message: ChatMessage) async {
        await mutateHistory { history in
            if let index = history.firstIndex(where: { $0.id == message.id }) {
                history[index].mergeMessage(with: message)
                
            } else {
                history.append(message)
            }
        }
    }

    /// Remove a message from the history.
    func removeMessage(_ id: String) async {
        await mutateHistory {
            $0.removeAll { $0.id == id }
        }
    }

    /// Clear the history.
    func clearHistory() async {
        await mutateHistory { $0.removeAll() }
    }
}

extension ChatMessage {
    mutating func mergeMessage(with message: ChatMessage) {
        // merge content
        self.content = self.content + message.content
        
        // merge references
        var seen = Set<ConversationReference>()
        // without duplicated and keep order
        self.references = (self.references + message.references).filter { seen.insert($0).inserted }
        
        // merge followUp
        self.followUp = message.followUp ?? self.followUp
        
        // merge suggested title
        self.suggestedTitle = message.suggestedTitle ?? self.suggestedTitle
        
        // merge error message
        if let errorMessage = message.errorMessage {
            self.errorMessage = (self.errorMessage ?? "") + errorMessage
        }
        
        // merge steps
        if !message.steps.isEmpty {
            var mergedSteps = self.steps
            
            for newStep in message.steps {
                if let index = mergedSteps.firstIndex(where: { $0.id == newStep.id }) {
                    mergedSteps[index] = newStep
                } else {
                    mergedSteps.append(newStep)
                }
            }
            
            self.steps = mergedSteps
        }
    }
}
