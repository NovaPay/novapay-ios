public struct Recipient: Encodable, Decodable {
    let type: String
    let identifier: String?
    let amount: String? // Using Any to handle both String and Double
    let payment_type: String
    let first_name: String?
    let last_name: String?
    let patronymic: String?
    let phone: String?
    let tax_payer: String?
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        if let identifier = identifier {
            try container.encode(identifier, forKey: .identifier)
        }
        
        // Handle amount which can be String or Double
        if let stringAmount = amount {
            try container.encode(stringAmount, forKey: .amount)
        }
        
        try container.encode(payment_type, forKey: .payment_type)
        
        if let first_name = first_name {
            try container.encode(first_name, forKey: .first_name)
        }
        
        if let last_name = last_name {
            try container.encode(last_name, forKey: .last_name)
        }
        
        if let patronymic = patronymic {
            try container.encode(patronymic, forKey: .patronymic)
        }
        
        if let phone = phone {
            try container.encode(phone, forKey: .phone)
        }
        
        if let tax_payer = tax_payer {
            try container.encode(tax_payer, forKey: .tax_payer)
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, identifier, amount, payment_type, first_name, last_name, patronymic, phone, tax_payer
    }
}
