import Vapor

final class User {
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

extension User: JsonRepresentable {
    func makeJson() -> Json {
        return Json([
            "name": "\(name)"
        ])
    }
}

extension User: CustomStringConvertible {
    var description: String {
        return "[User: \(name)]"
    }
}

extension User: StringInitializable {
    convenience init?(from string: String) throws {
        print(string)
        self.init(name: string)
    }
}