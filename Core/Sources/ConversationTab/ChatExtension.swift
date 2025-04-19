import ChatService
import ConversationServiceProvider

extension Chat.State {
    func buildSkillSet() -> [ConversationSkill] {
        guard let currentFile = self.currentEditor else {
            return []
        }
        let fileReference = FileReference(
            url: currentFile.url,
            relativePath: currentFile.relativePath,
            fileName: currentFile.fileName,
            isCurrentEditor: currentFile.isCurrentEditor
        )
        return [CurrentEditorSkill(currentFile: fileReference), ProblemsInActiveDocumentSkill()]
    }
}
