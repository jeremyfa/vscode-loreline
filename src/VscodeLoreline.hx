package;

import js.Node;
import js.node.Fs;
import js.node.Path;
import tracker.Model;
import vscode.ExtensionContext;
import vscode.OutputChannel;

// Initialize node require
@:jsRequire("module") extern class Module {
    static function createRequire(path:String):Dynamic;
}

// VSCode LSP Client externs
@:jsRequire("vscode-languageclient/node", "LanguageClient")
extern class LanguageClient {
    function new(id:String, name:String, serverOptions:Dynamic, clientOptions:Dynamic);
    function start():js.lib.Promise<Dynamic>;
    function stop():js.lib.Promise<Dynamic>;
    function dispose():Void;
    function onDidChangeState(handler:Dynamic->Void):Void;
}

class VscodeLoreline extends Model {

    /// Exposed

    static var instance:VscodeLoreline = null;

    @:expose("activate")
    static function activate(context:ExtensionContext) {
        instance = new VscodeLoreline(context);
        return instance.activationPromise;
    }

    @:expose("deactivate")
    static function deactivate() {
        if (instance != null) {
            instance.dispose();
            instance = null;
        }
    }

    /// Properties

    var context:ExtensionContext;
    var lspClient:LanguageClient;
    var lspOutputChannel:OutputChannel;
    var activationPromise:js.lib.Promise<Dynamic>;
    var disposed:Bool = false;

    /// Lifecycle

    function new(context:ExtensionContext) {
        super();
        this.context = context;

        // Create output channel first
        lspOutputChannel = Vscode.window.createOutputChannel("Loreline");
        lspOutputChannel.show(true);

        // Log initialization
        lspOutputChannel.appendLine("Initializing Loreline Language Client...");
        trace("INITIALIZE LORELINE CLIENT");

        // Create activation promise
        activationPromise = createClient();
    }

    function createClient():js.lib.Promise<Dynamic> {
        return new js.lib.Promise(function(resolve:Dynamic->Void, reject:Dynamic->Void):Void {
            try {
                // Setup require for the current file's directory
                final require = Module.createRequire(Node.__filename);

                // Get server module path
                final serverModule = Path.join(context.extensionPath, 'loreline-server.js');
                lspOutputChannel.appendLine('Server module path: ${serverModule}');

                // Setup server options
                final serverOptions = {
                    run: {
                        module: serverModule,
                        transport: require('vscode-languageclient/node').TransportKind.ipc,
                        options: {
                            cwd: context.extensionPath
                        }
                    },
                    debug: {
                        module: serverModule,
                        transport: require('vscode-languageclient/node').TransportKind.ipc,
                        options: {
                            execArgv: ["--nolazy", "--inspect=6009"],
                            cwd: context.extensionPath
                        }
                    }
                };

                // Setup client options
                final clientOptions = {
                    documentSelector: [{
                        scheme: "file",
                        language: "loreline"
                    }],
                    synchronize: {
                        fileEvents: Vscode.workspace.createFileSystemWatcher("**/*.lor")
                    },
                    outputChannel: lspOutputChannel,
                    errorHandler: {
                        error: function(error:Dynamic, message:String, count:Int):Dynamic {
                            lspOutputChannel.appendLine('Error: ${message} (${error})');
                            return require('vscode-languageclient').ErrorAction.Continue;
                        },
                        closed: function():Dynamic {
                            lspOutputChannel.appendLine('Connection closed');
                            return require('vscode-languageclient').CloseAction.DoNotRestart;
                        }
                    }
                };

                // Create client
                lspClient = new LanguageClient(
                    "loreline-language-server",
                    "Loreline Language Server",
                    serverOptions,
                    clientOptions
                );

                // Handle state changes
                lspClient.onDidChangeState(function(event:Dynamic) {
                    lspOutputChannel.appendLine('Client state changed: ${haxe.Json.stringify(event)}');
                });

                // Start the client
                context.subscriptions.push(cast lspClient);
                lspClient.start().then(function(value:Dynamic) {
                    lspOutputChannel.appendLine("Client started successfully");
                    resolve(value);
                    return value;
                }, function(error:Dynamic) {
                    lspOutputChannel.appendLine('Failed to start client: ${error}');
                    reject(error);
                    return error;
                });
            }
            catch (e:Dynamic) {
                lspOutputChannel.appendLine('Error creating client: ${e}');
                reject(e);
            }
        });
    }

    function dispose() {
        if (!disposed) {
            disposed = true;
            lspOutputChannel.appendLine("Disposing Loreline extension...");

            if (lspClient != null) {
                lspClient.stop().then(function(value:Dynamic) {
                    lspOutputChannel.dispose();
                    lspOutputChannel = null;
                    lspClient.dispose();
                    lspClient = null;
                    return value;
                });
            } else if (lspOutputChannel != null) {
                lspOutputChannel.dispose();
                lspOutputChannel = null;
            }
        }
    }

}