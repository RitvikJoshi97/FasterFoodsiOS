import Foundation

struct ReceiptScanResult: Identifiable, Decodable, Equatable {
    let id: UUID
    let store: String
    let dateOnReceipt: String?
    let processingDate: String
    let items: [ReceiptScanItem]

    private enum CodingKeys: String, CodingKey {
        case store
        case dateOnReceipt = "date_on_receipt"
        case processingDate = "processing_date"
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        store = try container.decode(String.self, forKey: .store)
        dateOnReceipt = try container.decodeIfPresent(String.self, forKey: .dateOnReceipt)
        processingDate = try container.decode(String.self, forKey: .processingDate)
        items = try container.decode([ReceiptScanItem].self, forKey: .items)
    }
}

struct ReceiptScanItem: Identifiable, Decodable, Equatable {
    let id: UUID
    let name: String
    var estimatedName: String

    private enum CodingKeys: String, CodingKey {
        case name
        case estimatedName = "estimated_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try container.decode(String.self, forKey: .name)
        estimatedName = try container.decode(String.self, forKey: .estimatedName)
    }
}

extension ReceiptScanResult {
    static let mockJSON: String = """
        {
          "store": "Sainsbury's",
          "date_on_receipt": "",
          "processing_date": "2026-01-01",
          "items": [
            {
              "name": "BASICS DT LEMNDE 2L",
              "estimated_name": "Sainsbury's Basics Diet Lemonade 2L"
            },
            {
              "name": "BASICS DIET COLA 2L",
              "estimated_name": "Sainsbury's Basics Diet Cola 2L"
            },
            {
              "name": "BASICS BEANS",
              "estimated_name": "Sainsbury's Basics Baked Beans"
            },
            {
              "name": "BASICS BEANS",
              "estimated_name": "Sainsbury's Basics Baked Beans"
            },
            {
              "name": "BASICS BEANS",
              "estimated_name": "Sainsbury's Basics Baked Beans"
            },
            {
              "name": "BASICS BEANS",
              "estimated_name": "Sainsbury's Basics Baked Beans"
            },
            {
              "name": "BASICS CRM CHAN SOUP",
              "estimated_name": "Sainsbury's Basics Cream Soup"
            },
            {
              "name": "BASICS PLN FLR 1.5K",
              "estimated_name": "Sainsbury's Basics Plain Flour 1.5kg"
            },
            {
              "name": "JS SEMI SKIMMED MLK",
              "estimated_name": "J Sainsbury's Semi-Skimmed Milk"
            },
            {
              "name": "BASICS TABLE SALT",
              "estimated_name": "Sainsbury's Basics Table Salt"
            },
            {
              "name": "IS FC JUICE",
              "estimated_name": "Sainsbury's Fruit Juice"
            },
            {
              "name": "BASICS TOMATO SOUP",
              "estimated_name": "Sainsbury's Basics Tomato Soup"
            },
            {
              "name": "BASICS GRATED CHEESE",
              "estimated_name": "Sainsbury's Basics Grated Cheese"
            },
            {
              "name": "JS FAST ACT YEAST",
              "estimated_name": "J Sainsbury's Fast Action Yeast"
            },
            {
              "name": "BASICS LAGER 4X440",
              "estimated_name": "Sainsbury's Basics Lager 4 x 440ml"
            },
            {
              "name": "BASICS L/P MSHY PEAS",
              "estimated_name": "Sainsbury's Basics Mushy Peas"
            },
            {
              "name": "BASICS CURRY NOODLES",
              "estimated_name": "Sainsbury's Basics Curry Noodles"
            },
            {
              "name": "BASICS CRM CHKN SOUP",
              "estimated_name": "Sainsbury's Basics Cream of Chicken Soup"
            },
            {
              "name": "BASICS VEGTABLE SOUP",
              "estimated_name": "Sainsbury's Basics Vegetable Soup"
            },
            {
              "name": "BASICS VEGTABLE SOUP",
              "estimated_name": "Sainsbury's Basics Vegetable Soup"
            },
            {
              "name": "BASICS VEGTABLE SOUP",
              "estimated_name": "Sainsbury's Basics Vegetable Soup"
            },
            {
              "name": "BASICS L/P MSHY PEAS",
              "estimated_name": "Sainsbury's Basics Mushy Peas"
            },
            {
              "name": "BASICS CHICKEN NOLE",
              "estimated_name": "Sainsbury's Basics Chicken Noodles"
            },
            {
              "name": "BASICS COCKTAIL",
              "estimated_name": "Sainsbury's Basics Fruit Cocktail"
            },
            {
              "name": "BASICS CURRY NOODLES",
              "estimated_name": "Sainsbury's Basics Curry Noodles"
            },
            {
              "name": "BASICS CURRY NOODLES",
              "estimated_name": "Sainsbury's Basics Curry Noodles"
            },
            {
              "name": "US BAKING POTATOES",
              "estimated_name": "Loose Baking Potatoes"
            },
            {
              "name": "JS C CUP MUSHROOMS",
              "estimated_name": "J Sainsbury's Closed Cup Mushrooms"
            },
            {
              "name": "BASICS CHICKEN NOLE",
              "estimated_name": "Sainsbury's Basics Chicken Noodles"
            },
            {
              "name": "BASICS CHICKEN NOLE",
              "estimated_name": "Sainsbury's Basics Chicken Noodles"
            },
            {
              "name": "JS 21b loaf tin",
              "estimated_name": "J Sainsbury's 2lb Loaf Tin"
            }
          ]
        }
        """

    static func mockResult() -> ReceiptScanResult? {
        guard let data = mockJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ReceiptScanResult.self, from: data)
    }
}
