import CoreData
import HeartbeatCore

final class SessionStore: @unchecked Sendable {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    init() throws {
        func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
            let a = NSAttributeDescription(); a.name = name; a.attributeType = type; a.isOptional = optional; return a
        }
        func entity(_ name: String, _ fields: [NSAttributeDescription]) -> NSEntityDescription {
            let e = NSEntityDescription(); e.name = name; e.managedObjectClassName = "NSManagedObject"; e.properties = fields; e.uniquenessConstraints = [["id"]]; return e
        }
        let model = NSManagedObjectModel()
        model.entities = [
            entity("Session", [attribute("id", .UUIDAttributeType), attribute("startedAt", .dateAttributeType), attribute("endedAt", .dateAttributeType, optional: true), attribute("mode", .stringAttributeType), attribute("reason", .stringAttributeType)]),
            entity("Measurement", [attribute("id", .UUIDAttributeType), attribute("sessionID", .UUIDAttributeType), attribute("timestamp", .dateAttributeType), attribute("receivedAt", .dateAttributeType), attribute("bpm", .doubleAttributeType), attribute("source", .stringAttributeType)]),
            entity("Event", [attribute("id", .UUIDAttributeType), attribute("sessionID", .UUIDAttributeType), attribute("date", .dateAttributeType), attribute("text", .stringAttributeType)])
        ]
        container = NSPersistentContainer(name: "Heartbeat", managedObjectModel: model)
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let description = NSPersistentStoreDescription(url: directory.appendingPathComponent("Heartbeat.sqlite"))
        description.shouldAddStoreAsynchronously = false
        description.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        var failure: Error?
        container.loadPersistentStores { _, error in failure = error }
        if let failure { throw failure }
        context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func begin(at date: Date, mode: String, reason: String) async throws -> UUID {
        try await context.perform {
            let id = UUID(); let object = NSEntityDescription.insertNewObject(forEntityName: "Session", into: self.context)
            object.setValue(id, forKey: "id"); object.setValue(date, forKey: "startedAt")
            object.setValue(mode, forKey: "mode"); object.setValue(reason, forKey: "reason")
            try self.context.save(); return id
        }
    }
    func append(_ sample: HeartRateSample, sessionID: UUID) async throws {
        try await context.perform {
            let item = NSEntityDescription.insertNewObject(forEntityName: "Measurement", into: self.context)
            for (key, value) in ["id": sample.id, "sessionID": sessionID, "timestamp": sample.timestamp, "receivedAt": sample.receivedAt, "bpm": sample.bpm, "source": sample.source] as [String: Any] { item.setValue(value, forKey: key) }
            try self.context.save()
        }
    }
    func event(_ text: String, at date: Date = Date(), sessionID: UUID) async throws {
        try await context.perform {
            let item = NSEntityDescription.insertNewObject(forEntityName: "Event", into: self.context)
            item.setValue(UUID(), forKey: "id"); item.setValue(sessionID, forKey: "sessionID")
            item.setValue(date, forKey: "date"); item.setValue(text, forKey: "text"); try self.context.save()
        }
    }
    func end(_ id: UUID, at date: Date, reason: String) async throws {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Session"); request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
            if let object = try self.context.fetch(request).first {
                object.setValue(date, forKey: "endedAt"); object.setValue(reason, forKey: "reason"); try self.context.save()
            }
        }
    }
    func samples(for id: UUID) async throws -> [HeartRateSample] {
        try await context.perform { try self.readSamples(id) }
    }
    private func readSamples(_ id: UUID) throws -> [HeartRateSample] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Measurement")
        request.predicate = NSPredicate(format: "sessionID == %@", id as NSUUID)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return try context.fetch(request).compactMap { item in
            guard let id = item.value(forKey: "id") as? UUID, let timestamp = item.value(forKey: "timestamp") as? Date, let receivedAt = item.value(forKey: "receivedAt") as? Date, let bpm = item.value(forKey: "bpm") as? Double, let source = item.value(forKey: "source") as? String else { return nil }
            return HeartRateSample(id: id, bpm: bpm, timestamp: timestamp, receivedAt: receivedAt, source: source)
        }
    }
    func sessions() async throws -> [SessionSummary] {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Session"); request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            return try self.context.fetch(request).compactMap { item in
                guard let id = item.value(forKey: "id") as? UUID, let date = item.value(forKey: "startedAt") as? Date else { return nil }
                let values = try self.readSamples(id).map(\.bpm)
                return SessionSummary(id: id, startedAt: date, endedAt: item.value(forKey: "endedAt") as? Date, mode: item.value(forKey: "mode") as? String ?? "", reason: item.value(forKey: "reason") as? String ?? "", count: values.count, average: values.isEmpty ? nil : values.reduce(0, +) / Double(values.count), minimum: values.min(), maximum: values.max())
            }
        }
    }
    func events(for id: UUID) async throws -> [StoredEvent] {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Event"); request.predicate = NSPredicate(format: "sessionID == %@", id as NSUUID); request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            return try self.context.fetch(request).compactMap { object in
                guard let id = object.value(forKey: "id") as? UUID, let date = object.value(forKey: "date") as? Date, let text = object.value(forKey: "text") as? String else { return nil }
                return .init(id: id, date: date, text: text)
            }
        }
    }
    func recoverInterrupted() async throws {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Session"); request.predicate = NSPredicate(format: "endedAt == nil")
            for session in try self.context.fetch(request) {
                guard let id = session.value(forKey: "id") as? UUID else { continue }
                let last = try self.readSamples(id).last?.timestamp ?? session.value(forKey: "startedAt") as? Date ?? Date()
                session.setValue(last, forKey: "endedAt"); session.setValue("Onderbroken; app opnieuw geopend", forKey: "reason")
            }
            try self.context.save()
        }
    }
    func prune(days: Int) async throws {
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Session"); request.predicate = NSPredicate(format: "endedAt < %@", cutoff as NSDate)
            for item in try self.context.fetch(request) {
                if let id = item.value(forKey: "id") as? UUID { try self.deleteChildren(id) }
                self.context.delete(item)
            }
            try self.context.save()
        }
    }
    private func deleteChildren(_ id: UUID) throws {
        for name in ["Measurement", "Event"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: name); request.predicate = NSPredicate(format: "sessionID == %@", id as NSUUID)
            for item in try context.fetch(request) { context.delete(item) }
        }
    }
    func deleteAll() async throws {
        try await context.perform {
            for name in ["Measurement", "Event", "Session"] {
                let request = NSFetchRequest<NSManagedObject>(entityName: name)
                for item in try self.context.fetch(request) { self.context.delete(item) }
            }
            try self.context.save()
        }
    }
}
