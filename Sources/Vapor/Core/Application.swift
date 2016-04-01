import libc
import Hummingbird

public class Application {
    public static let VERSION = "0.4.1"

    /**
        The router driver is responsible
        for returning registered `Route` handlers
        for a given request.
    */
    public var router: RouterDriver = BranchRouter()

    /**
        The server driver is responsible
        for handling connections on the desired port.
        This property is constant since it cannot
        be changed after the server has been booted.
    */
    public var server: ServerDriver = Jeeves<Hummingbird.Socket>()

    /**
        The session driver is responsible for
        storing and reading values written to the
        users session.
    */
    public lazy var session: SessionDriver = MemorySessionDriver(application: self)

    /**
        Provides access to config settings.
    */
    public lazy var config: Config = Config(application: self)
    
    /**
        Provides access to the underlying
        `HashDriver`.
    */
    public private(set) lazy var hash: Hash = Hash()

    /**
        `Middleware` will be applied in the order
        it is set in this array.

        Make sure to append your custom `Middleware`
        if you don't want to overwrite default behavior.
    */
    public var middleware: [Middleware.Type]

    /**
        Provider classes that have been registered
        with this application
    */
    public var providers: [Provider.Type]

    /**
        Internal value populated the first time
        self.environment is computed
    */
    private var detectedEnvironment: Environment?

    /**
        Current environment of the application
    */
    public var environment: Environment {
        if let environment = self.detectedEnvironment {
            return environment
        }

        let environment = bootEnvironment()
        self.detectedEnvironment = environment
        return environment
    }

    /**
        Optional handler to be called when detecting the
        current environment.
    */
    public var detectEnvironmentHandler: ((String) -> Environment)?

    /**
        The work directory of your application is
        the directory in which your Resources, Public, etc
        folders are stored. This is normally `./` if
        you are running Vapor using `.build/xxx/App`
    */
    public var workDir = "./" {
        didSet {
            if self.workDir.characters.last != "/" {
                self.workDir += "/"
            }
        }
    }

    var scopedHost: String?
    var scopedMiddleware: [Middleware.Type] = []
    var scopedPrefix: String?

    var port: Int = 80
    var ip: String = "0.0.0.0"

    var routes: [Route] = []

    /**
        Initialize the Application.
    */
    public init() {
        self.middleware = [
            AbortMiddleware.self,
            SessionMiddleware.self
        ]

        self.providers = []
    }

    public func bootProviders() {
        for provider in self.providers {
            provider.boot(self)
        }
    }

    func bootEnvironment() -> Environment {
        var environment: String

        if let value = Process.valueFor(argument: "env") {
            Log.info("Environment override: \(value)")
            environment = value
        } else {
            // TODO: This should default to "production" in release builds
            environment = "development"
        }

        if let handler = self.detectEnvironmentHandler {
            return handler(environment)
        } else {
            return Environment.fromString(environment)
        }
    }

    /**
        If multiple environments are passed, return
        value will be true if at least one of the passed
        in environment values matches the app environment
        and false if none of them match.

        If a single environment is passed, the return
        value will be true if the the passed in environment
        matches the app environment.
    */
    public func inEnvironment(environments: Environment...) -> Bool {
        if environments.count == 1 {
            return self.environment == environments[0]
        } else {
            return environments.contains(self.environment)
        }
    }

    func bootRoutes() {
        routes.forEach(router.register)
    }

    func bootArguments() {
        //grab process args
        if let workDir = Process.valueFor(argument: "workDir") {
            Log.info("Work dir override: \(workDir)")
            self.workDir = workDir
        }

        if let ip = Process.valueFor(argument: "ip") {
            Log.info("IP override: \(ip)")
            self.ip = ip
        }

        if let port = Process.valueFor(argument: "port")?.int {
            Log.info("Port override: \(port)")
            self.port = port
        }
    }

    /**
        Boots the chosen server driver and
        optionally runs on the supplied
        ip & port overrides
    */
    public func start(ip ip: String? = nil, port: Int? = nil) {
        bootProviders()
        server.delegate = self

        self.ip = ip ?? self.ip
        self.port = port ?? self.port

        bootRoutes()
        bootArguments()
        
        if environment == .Production {
            Log.info("Production mode detected, disabling information logs.")
            Log.enabledLevels = [.Error, .Fatal]
        }

        do {
            Log.info("Server starting on \(self.ip):\(self.port)")
            try server.boot(ip: self.ip, port: self.port)
        } catch {
            Log.error("Server start error: \(error)")
        }
    }

    func checkFileSystem(request: Request) -> Request.Handler? {
        // Check in file system
        let filePath = self.workDir + "Public" + request.path

        guard FileManager.fileAtPath(filePath).exists else {
            return nil
        }

        // File exists
        if let fileBody = try? FileManager.readBytesFromFile(filePath) {
            return { _ in
                return Response(status: .OK, data: fileBody, contentType: .None)
            }
        } else {
            return { _ in
                Log.warning("Could not open file, returning 404")
                return Response(status: .NotFound, text: "Page not found")
            }
        }
    }
}

extension Application: ServerDriverDelegate {

    public func serverDriverDidReceiveRequest(request: Request) -> Response {
        var handler: Request.Handler

        // Check in routes
        if let routerHandler = router.route(request) {
            handler = routerHandler
        } else if let fileHander = self.checkFileSystem(request) {
            handler = fileHander
        } else {
            // Default not found handler
            handler = { _ in
                return Response(status: .NotFound, text: "Page not found")
            }
        }

        // Loop through middlewares in order
        for middleware in self.middleware {
            handler = middleware.handle(handler, for: self)
        }

        do {
            let response = try handler(request: request)

            if response.headers["Content-Type"] == nil {
                Log.warning("Response had no 'Content-Type' header.")
            }

            return response
        } catch {
            var error = "Server Error: \(error)"
            if environment == .Production {
                error = "Something went wrong"
            }
            
            return Response(error: error)
        }

    }

}
