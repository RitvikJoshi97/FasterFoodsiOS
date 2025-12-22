import Foundation

enum OutboxOperationKind: String, Codable {
    case createShoppingList
    case addShoppingItem
    case toggleShoppingItem
    case deleteShoppingItem
    case deleteShoppingList
    case addPantryItem
    case updatePantryItem
    case togglePantryItem
    case deletePantryItem
    case addFoodLogItem
    case deleteFoodLogItem
    case addWorkout
    case deleteWorkout
    case addCustomMetric
    case deleteCustomMetric
}

struct OutboxOperation: Codable, Identifiable {
    let id: UUID
    let kind: OutboxOperationKind
    var payload: Data
    let createdAt: Date

    init(id: UUID = UUID(), kind: OutboxOperationKind, payload: Data, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.payload = payload
        self.createdAt = createdAt
    }
}

struct CreateShoppingListPayload: Codable {
    let tempId: String
    let name: String
}

struct AddShoppingItemPayload: Codable {
    let tempItemId: String
    var listId: String
    let name: String
    let quantity: String?
    let unit: String?
    let listLabel: String?
}

struct ToggleShoppingItemPayload: Codable {
    var listId: String
    var itemId: String
    let checked: Bool
    let checkedAt: Int?
}

struct DeleteShoppingItemPayload: Codable {
    var listId: String
    var itemId: String
}

struct DeleteShoppingListPayload: Codable {
    var listId: String
}

struct AddPantryItemPayload: Codable {
    let tempId: String
    let name: String
    let quantity: String?
    let unit: String?
    let expiryDate: String?
}

struct UpdatePantryItemPayload: Codable {
    var id: String
    let name: String?
    let quantity: String?
    let unit: String?
    let expiryDate: String?
}

struct TogglePantryItemPayload: Codable {
    var id: String
}

struct DeletePantryItemPayload: Codable {
    var id: String
}

struct AddFoodLogItemPayload: Codable {
    let tempId: String
    let request: FoodLogCreateRequest
}

struct DeleteFoodLogItemPayload: Codable {
    var id: String
}

struct AddWorkoutPayload: Codable {
    let tempId: String
    let item: WorkoutLogItem
}

struct DeleteWorkoutPayload: Codable {
    var id: String
}

struct AddCustomMetricPayload: Codable {
    let tempId: String
    let metric: CustomMetric
}

struct DeleteCustomMetricPayload: Codable {
    var id: String
}

actor OfflineOutbox {
    static let shared = OfflineOutbox()

    private let fileName = "offline_outbox.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var operations: [OutboxOperation] = []

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        loadFromDisk()
    }

    func enqueue(_ operation: OutboxOperation) {
        operations.append(operation)
        persist()
    }

    func all() -> [OutboxOperation] {
        operations
    }

    func remove(_ id: UUID) {
        operations.removeAll { $0.id == id }
        persist()
    }

    func removeOperations(where shouldRemove: (OutboxOperation) -> Bool) {
        operations.removeAll(where: shouldRemove)
        persist()
    }

    func removeOperations(forTempShoppingListId id: String) {
        removeOperations { operation in
            switch operation.kind {
            case .createShoppingList:
                guard let payload = decode(CreateShoppingListPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.tempId == id
            case .addShoppingItem:
                guard let payload = decode(AddShoppingItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.listId == id
            case .toggleShoppingItem:
                guard let payload = decode(ToggleShoppingItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.listId == id
            case .deleteShoppingItem:
                guard let payload = decode(DeleteShoppingItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.listId == id
            case .deleteShoppingList:
                guard let payload = decode(DeleteShoppingListPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.listId == id
            default:
                return false
            }
        }
    }

    func removeOperations(forTempShoppingItemId id: String) {
        removeOperations { operation in
            switch operation.kind {
            case .addShoppingItem:
                guard let payload = decode(AddShoppingItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.tempItemId == id
            case .toggleShoppingItem:
                guard let payload = decode(ToggleShoppingItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.itemId == id
            case .deleteShoppingItem:
                guard let payload = decode(DeleteShoppingItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.itemId == id
            default:
                return false
            }
        }
    }

    func removeOperations(forTempPantryItemId id: String) {
        removeOperations { operation in
            switch operation.kind {
            case .addPantryItem:
                guard let payload = decode(AddPantryItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.tempId == id
            case .updatePantryItem:
                guard let payload = decode(UpdatePantryItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.id == id
            case .togglePantryItem:
                guard let payload = decode(TogglePantryItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.id == id
            case .deletePantryItem:
                guard let payload = decode(DeletePantryItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.id == id
            default:
                return false
            }
        }
    }

    func removeOperations(forTempFoodLogId id: String) {
        removeOperations { operation in
            switch operation.kind {
            case .addFoodLogItem:
                guard let payload = decode(AddFoodLogItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.tempId == id
            case .deleteFoodLogItem:
                guard let payload = decode(DeleteFoodLogItemPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.id == id
            default:
                return false
            }
        }
    }

    func removeOperations(forTempWorkoutId id: String) {
        removeOperations { operation in
            switch operation.kind {
            case .addWorkout:
                guard let payload = decode(AddWorkoutPayload.self, from: operation.payload) else {
                    return false
                }
                return payload.tempId == id
            case .deleteWorkout:
                guard let payload = decode(DeleteWorkoutPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.id == id
            default:
                return false
            }
        }
    }

    func removeOperations(forTempCustomMetricId id: String) {
        removeOperations { operation in
            switch operation.kind {
            case .addCustomMetric:
                guard let payload = decode(AddCustomMetricPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.tempId == id
            case .deleteCustomMetric:
                guard let payload = decode(DeleteCustomMetricPayload.self, from: operation.payload)
                else {
                    return false
                }
                return payload.id == id
            default:
                return false
            }
        }
    }

    func replaceShoppingListId(oldId: String, newId: String) {
        mutateOperations { operation in
            switch operation.kind {
            case .addShoppingItem:
                guard var payload = decode(AddShoppingItemPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.listId == oldId {
                    payload.listId = newId
                    return encode(payload, for: operation)
                }
            case .toggleShoppingItem:
                guard var payload = decode(ToggleShoppingItemPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.listId == oldId {
                    payload.listId = newId
                    return encode(payload, for: operation)
                }
            case .deleteShoppingItem:
                guard var payload = decode(DeleteShoppingItemPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.listId == oldId {
                    payload.listId = newId
                    return encode(payload, for: operation)
                }
            case .deleteShoppingList:
                guard var payload = decode(DeleteShoppingListPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.listId == oldId {
                    payload.listId = newId
                    return encode(payload, for: operation)
                }
            default:
                break
            }
            return operation
        }
    }

    func replaceShoppingItemId(oldId: String, newId: String) {
        mutateOperations { operation in
            switch operation.kind {
            case .toggleShoppingItem:
                guard var payload = decode(ToggleShoppingItemPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.itemId == oldId {
                    payload.itemId = newId
                    return encode(payload, for: operation)
                }
            case .deleteShoppingItem:
                guard var payload = decode(DeleteShoppingItemPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.itemId == oldId {
                    payload.itemId = newId
                    return encode(payload, for: operation)
                }
            default:
                break
            }
            return operation
        }
    }

    func replacePantryItemId(oldId: String, newId: String) {
        mutateOperations { operation in
            switch operation.kind {
            case .updatePantryItem:
                guard var payload = decode(UpdatePantryItemPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.id == oldId {
                    payload.id = newId
                    return encode(payload, for: operation)
                }
            case .togglePantryItem:
                guard var payload = decode(TogglePantryItemPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.id == oldId {
                    payload.id = newId
                    return encode(payload, for: operation)
                }
            case .deletePantryItem:
                guard var payload = decode(DeletePantryItemPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.id == oldId {
                    payload.id = newId
                    return encode(payload, for: operation)
                }
            default:
                break
            }
            return operation
        }
    }

    func replaceFoodLogId(oldId: String, newId: String) {
        mutateOperations { operation in
            switch operation.kind {
            case .deleteFoodLogItem:
                guard var payload = decode(DeleteFoodLogItemPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.id == oldId {
                    payload.id = newId
                    return encode(payload, for: operation)
                }
            default:
                break
            }
            return operation
        }
    }

    func replaceWorkoutId(oldId: String, newId: String) {
        mutateOperations { operation in
            switch operation.kind {
            case .deleteWorkout:
                guard var payload = decode(DeleteWorkoutPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.id == oldId {
                    payload.id = newId
                    return encode(payload, for: operation)
                }
            default:
                break
            }
            return operation
        }
    }

    func replaceCustomMetricId(oldId: String, newId: String) {
        mutateOperations { operation in
            switch operation.kind {
            case .deleteCustomMetric:
                guard var payload = decode(DeleteCustomMetricPayload.self, from: operation.payload)
                else {
                    return operation
                }
                if payload.id == oldId {
                    payload.id = newId
                    return encode(payload, for: operation)
                }
            default:
                break
            }
            return operation
        }
    }

    func decodePayload<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        decode(type, from: data)
    }

    private func loadFromDisk() {
        let url = cacheURL()
        guard let data = try? Data(contentsOf: url),
            let decoded = try? decoder.decode([OutboxOperation].self, from: data)
        else {
            return
        }
        operations = decoded
    }

    private func persist() {
        let url = cacheURL()
        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: nil)
            let data = try encoder.encode(operations)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("⚠️ Failed to persist outbox: \(error)")
        }
    }

    private func cacheURL() -> URL {
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedContainer.identifier)
        {
            return
                url
                .appendingPathComponent("OfflineCache", isDirectory: true)
                .appendingPathComponent(fileName)
        }

        let base =
            FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return
            base
            .appendingPathComponent("OfflineCache", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private func mutateOperations(_ transform: (OutboxOperation) -> OutboxOperation) {
        operations = operations.map(transform)
        persist()
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? decoder.decode(type, from: data)
    }

    private func encode<T: Encodable>(_ payload: T, for operation: OutboxOperation)
        -> OutboxOperation
    {
        let encoded = (try? encoder.encode(payload)) ?? operation.payload
        return OutboxOperation(
            id: operation.id, kind: operation.kind, payload: encoded, createdAt: operation.createdAt
        )
    }
}
