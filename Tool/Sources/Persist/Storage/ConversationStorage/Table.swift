import SQLite

struct ConversationTable {
    let table = Table("Conversation")
    
    // Column
    struct Column {
        let id = SQLite.Expression<String>("id")
        let title = SQLite.Expression<String?>("title")
        // 0 -> false, 1 -> true
        let isSelected = SQLite.Expression<Bool>("isSelected")
        let CLSConversationID = SQLite.Expression<String>("CLSConversationID")
        // for extensibility purpose
        let data = SQLite.Expression<SQLite.Blob>("data")
        let createdAt = SQLite.Expression<Double>("createdAt")
        let updatedAt = SQLite.Expression<Double>("updatedAt")
    }
    
    let column = Column()
}

struct TurnTable {
    let table = Table("Turn")
    
    // Column
    struct Column {
        // an auto-incremental id genrated by SQLite
        let rowID = SQLite.Expression<Int64>("rowID")
        let id = SQLite.Expression<String>("id")
        let conversationID = SQLite.Expression<String>("conversationID")
        let CLSTurnID = SQLite.Expression<String>("CLSTurnID")
        let role = SQLite.Expression<String>("role")
        // for extensibility purpose
        let data = SQLite.Expression<SQLite.Blob>("data")
        let createdAt = SQLite.Expression<Double>("createdAt")
        let updatedAt = SQLite.Expression<Double>("updatedAt")
    }
    
    let column = Column()
}
