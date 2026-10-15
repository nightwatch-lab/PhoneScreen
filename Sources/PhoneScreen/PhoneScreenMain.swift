import Darwin
import Foundation

enum LaunchHandoff {
    static var url: URL?
}

@main
enum PhoneScreenMain {
    static func main() {
        var args = Array(CommandLine.arguments.dropFirst())
        if args.first == "--gui" {
            startGUI()
            return
        }
        let json = args.contains("--json")
        args.removeAll { $0 == "--json" }
        if args.isEmpty {
            startGUI()
            return
        }
        if let first = args.first, first.hasPrefix("-"), first != "--help", first != "-h" {
            startGUI()
            return
        }
        if args.count == 1, let url = URL(string: args[0]), url.scheme?.lowercased() == "phonescreen" {
            LaunchHandoff.url = url
            startGUI()
            return
        }
        CLIClient.run(arguments: args, json: json)
    }

    /// Leave the controlling terminal so a CLI-launched menu-bar process
    /// survives after the terminal closes.
    private static func startGUI() {
        _ = setsid()
        PhoneScreenApp.main()
    }
}
