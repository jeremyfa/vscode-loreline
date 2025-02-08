package;

import js.Node;
import loreline.lsp.Server;

// Initialize node require
@:jsRequire("module") extern class Module {
    static function createRequire(path:String):Dynamic;
}

// LSP types
typedef Connection = {
    function listen():Void;
    function onInitialize(handler:(params:Dynamic)->Dynamic):Void;
    function onInitialized(handler:(params:Dynamic)->Void):Void;
    function onDidOpenTextDocument(handler:(params:Dynamic)->Void):Void;
    function onDidChangeTextDocument(handler:(params:Dynamic)->Void):Void;
    function onDidSaveTextDocument(handler:(params:Dynamic)->Void):Void;
    function onDidCloseTextDocument(handler:(params:Dynamic)->Void):Void;
    function onCompletion(handler:(params:Dynamic)->Dynamic):Void;
    function onDefinition(handler:(params:Dynamic)->Dynamic):Void;
    function onHover(handler:(params:Dynamic)->Dynamic):Void;
    function onDocumentSymbol(handler:(params:Dynamic)->Dynamic):Void;
    function onDocumentFormatting(handler:(params:Dynamic)->Dynamic):Void;
    function onReferences(handler:(params:Dynamic)->Dynamic):Void;
    function onExit(handler:()->Void):Void;
    function onShutdown(handler:()->Void):Void;
    function sendDiagnostics(params:Dynamic):Void;
    var console:Logger;
}

// Logger interface
typedef Logger = {
    function log(message:String):Void;
    function info(message:String):Void;
    function warn(message:String):Void;
    function error(message:String):Void;
}

class LorelineServer {

    static final server = new Server();
    static var nextRequestId = 1;
    static var logger:Logger;

    static function main() {
        trace("INITIALIZE LORELINE SERVER");

        try {
            // Setup require for the current file's directory
            final require = Module.createRequire(Node.__filename);

            // Create LSP connection
            final connection:Connection = require('vscode-languageserver/node').createConnection();

            // Get logger
            logger = connection.console;
            logger.info('Loreline Language Server starting...');

            // Bind logger to server implementation
            server.onLog = (message:Any, ?pos:haxe.PosInfos) -> {
                logger.log(message);
            };

            haxe.Log.trace = server.onLog;

            // Listen to notifications sent back to client
            server.onNotification = message -> {
                // If response is a publishDiagnostics notification, send it through connection
                if (message.method == "textDocument/publishDiagnostics") {
                    connection.sendDiagnostics(message.params);
                }
            };

            // Initialize handlers
            connection.onInitialize(params -> {
                try {
                    logger.info('Initializing with params: ' + haxe.Json.stringify(params));
                    final response = server.handleMessage(makeRequest('initialize', params));
                    return response.result;
                }
                catch (e:Dynamic) {
                    logger.error('Error in onInitialize: ${e}');
                    throw e;
                }
            });

            connection.onInitialized(params -> {
                try {
                    logger.info('Server initialized');
                    server.handleMessage(makeNotification('initialized', params));
                }
                catch (e:Dynamic) {
                    logger.error('Error in onInitialized: ${e}');
                }
            });

            connection.onDidOpenTextDocument(params -> {
                try {
                    logger.info('Document opened: ' + params.textDocument.uri);
                    server.handleMessage(makeNotification('textDocument/didOpen', params));
                }
                catch (e:Dynamic) {
                    logger.error('Error in onDidOpenTextDocument: ${e}');
                }
            });

            connection.onDidChangeTextDocument(params -> {
                try {
                    logger.info('Document changed: ' + params.textDocument.uri);
                    server.handleMessage(makeNotification('textDocument/didChange', params));
                }
                catch (e:Dynamic) {
                    logger.error('Error in onDidChangeTextDocument: ${e}');
                }
            });

            connection.onDidSaveTextDocument(params -> {
                try {
                    logger.info('Document saved: ' + params.textDocument.uri);
                    server.handleMessage(makeNotification('textDocument/didSave', params));
                }
                catch (e:Dynamic) {
                    logger.error('Error in onDidSaveTextDocument: ${e}');
                }
            });

            connection.onDidCloseTextDocument(params -> {
                try {
                    logger.info('Document closed: ' + params.textDocument.uri);
                    server.handleMessage(makeNotification('textDocument/didClose', params));
                }
                catch (e:Dynamic) {
                    logger.error('Error in onDidCloseTextDocument: ${e}');
                }
            });

            connection.onCompletion(params -> {
                try {
                    logger.info('Completion requested');
                    final response = server.handleMessage(makeRequest('textDocument/completion', params));
                    return response.result;
                }
                catch (e:Dynamic) {
                    logger.error('Error in onCompletion: ${e}');
                    throw e;
                }
            });

            connection.onDefinition(params -> {
                try {
                    logger.info('Definition requested');
                    final response = server.handleMessage(makeRequest('textDocument/definition', params));
                    return response.result;
                }
                catch (e:Dynamic) {
                    logger.error('Error in onDefinition: ${e}');
                    throw e;
                }
            });

            connection.onHover(params -> {
                try {
                    logger.info('Hover requested');
                    final response = server.handleMessage(makeRequest('textDocument/hover', params));
                    return response.result;
                }
                catch (e:Dynamic) {
                    logger.error('Error in onHover: ${e}');
                    throw e;
                }
            });

            connection.onDocumentSymbol(params -> {
                try {
                    logger.info('Document symbols requested');
                    final response = server.handleMessage(makeRequest('textDocument/documentSymbol', params));
                    return response.result;
                }
                catch (e:Dynamic) {
                    logger.error('Error in onDocumentSymbol: ${e}');
                    throw e;
                }
            });

            connection.onDocumentFormatting(params -> {
                try {
                    logger.info('Document formatting requested');
                    final response = server.handleMessage(makeRequest('textDocument/formatting', params));
                    return response.result;
                }
                catch (e:Dynamic) {
                    logger.error('Error in onDocumentFormatting: ${e}');
                    throw e;
                }
            });

            connection.onReferences(params -> {
               try {
                   logger.info('References requested');
                   final response = server.handleMessage(makeRequest('textDocument/references', params));
                   return response.result;
               }
               catch (e:Dynamic) {
                   logger.error('Error in onReferences: ${e}');
                   throw e;
               }
            });

            // Handle shutdown/exit
            connection.onShutdown(() -> {
                logger.info('Server shutting down...');
            });

            connection.onExit(() -> {
                logger.info('Server exiting...');
                Node.process.exit(0);
            });

            // Start listening
            logger.info('Server starting...');
            connection.listen();
        }
        catch (e:Dynamic) {
            trace('Fatal server error: ${e}');
            if (e != null && e.stack != null) {
                trace(e.stack);
            }
            Node.process.exit(1);
        }
    }

    static function makeRequest(method:String, params:Dynamic):Dynamic {
        return {
            jsonrpc: "2.0",
            id: nextRequestId++,
            method: method,
            params: params
        };
    }

    static function makeNotification(method:String, params:Dynamic):Dynamic {
        return {
            jsonrpc: "2.0",
            method: method,
            params: params
        };
    }

}