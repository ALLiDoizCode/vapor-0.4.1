import Vapor

let app = Application()

app.hash.key = app.config.get("app.hash.key", "default-key")

//MARK: Basic

app.get("/") { request in
    return try app.view("welcome.html")
}

app.get("test") { request in
    return "123"
}

//MARK: Resource

app.resource("users", controller: UserController.self)

//MARK: Request data

app.post("jsondata") { request in
    print(request.data.json?["hi"]?.string)
    return "yup"
}

//MARK: Type safe routing

let i = Int.self
let s = String.self

app.get("test", i, s) { request, int, string in
    return Json([
        "message": "Int \(int) String \(string)"
    ])
}


//MARK: Json

app.get("json") { request in
    return Json([
        "number": 123,
        "text": "unicorns",
        "bool": false,
        "nested": ["one", 2, false]
    ])
}


app.post("json") { request in
    //parse a key inside the received json
    guard let count = request.data["unicorns"]?.int else {
        return Response(error: "No unicorn count provided")
    }
    return "Received \(count) unicorns"
}

app.get("redirect") { request in
    return Redirect(to: "http://qutheory.io:8001")
}

app.post("json2") { request in
    //parse a key inside the received json
    guard let count = request.data["unicorns"]?.int else {
        return Response(error: "No unicorn count provided")
    }
    return Response(status: .Created, json: Json(["message":"Received \(count) unicorns"]))
}

app.group("abort") {
    app.get("400") { request in
        throw Abort.BadRequest
    }
    
    app.get("404") { request in
        throw Abort.NotFound
    }
    
    app.get("420") { request in
        throw Abort.Custom(status: .Custom(420), message: "Enhance your calm")
    }
    
    app.get("500") { request in
        throw Abort.InternalServerError
    }
}

enum Error: ErrorProtocol {
    case Unhandled
}

app.get("error") { request in
    throw Error.Unhandled
}

//MARK: Session

app.get("session") { request in
    request.session?["name"] = "Vapor"
    return "Session set"
}


app.post("login") { request in
    guard
        let email = request.data["email"]?.string,
        let password = request.data["password"]?.string
    else {
        throw Abort.BadRequest
    }
    
    guard email == "user@qutheory.io" && password == "test123" else {
        throw Abort.BadRequest
    }
    
    request.session?["id"] = "123"
    
    return Json([
        "message": "Logged in"
    ])
}

//MARK: Middleware

app.middleware(AuthMiddleware.self) {
    app.get("protected") { request in
        return Json([
            "message": "Welcome authorized user"
        ])
    }
}

app.start(port: 8080)
