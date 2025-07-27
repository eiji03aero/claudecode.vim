const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { DiffHandler } = require('./handlers/diff');
const { ConnectionManager } = require('./handlers/connection');

// Set up logging to file
const setupLogging = () => {
  const vimProcessId = process.env.VIM_PROCESS_ID;
  if (!vimProcessId) {
    return;
  }
  
  const logDir = path.join(os.homedir(), '.claude', 'tmp');
  const logFile = path.join(logDir, `${vimProcessId}.log`);
  
  // Create log directory if it doesn't exist
  if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true, mode: 0o700 });
  }
  
  // Create log stream
  const logStream = fs.createWriteStream(logFile, { flags: 'a' });
  
  // Override console methods to write to log file
  const originalLog = console.log;
  const originalError = console.error;
  
  console.log = (...args) => {
    const timestamp = new Date().toISOString();
    const message = `[${timestamp}] LOG: ${args.join(' ')}\n`;
    logStream.write(message);
    originalLog.apply(console, args);
  };
  
  console.error = (...args) => {
    const timestamp = new Date().toISOString();
    const message = `[${timestamp}] ERROR: ${args.join(' ')}\n`;
    logStream.write(message);
    originalError.apply(console, args);
  };
  
  // Handle process exit to close log stream
  process.on('exit', () => {
    logStream.end();
  });
  
  console.log(`MCP Server logging to: ${logFile}`);
};

setupLogging();

class MCPServer {
  constructor() {
    this.server = null;
    this.vimClient = null;
    this.claudeClient = null;
    this.port = process.env.CLAUDE_CODE_SSE_PORT ? parseInt(process.env.CLAUDE_CODE_SSE_PORT) : 0;
    this.diffHandler = new DiffHandler();
    this.connectionManager = new ConnectionManager();
  }

  start() {
    this.server = new WebSocket.Server({ 
      port: this.port,
      host: '127.0.0.1'
    });

    this.server.on('listening', () => {
      console.log(`MCP server started on port guhehe ${this.port}`);
    });

    this.server.on('connection', (ws, req) => {
      console.log('New connection from', req.connection.remoteAddress);
      
      ws.on('message', (message) => {
        try {
          const data = JSON.parse(message);
          this.handleMessage(ws, data);
        } catch (error) {
          console.error('Error parsing message:', error);
          // this.sendError(ws, null, 'Invalid JSON', 'INVALID_JSON');
        }
      });

      ws.on('close', () => {
        console.log('Client disconnected');
        if (ws === this.vimClient) {
          console.log('Vim client disconnected, shutting down server');
          this.shutdown();
        }
      });

      ws.on('error', (error) => {
        console.error('WebSocket error:', error);
      });
    });

    this.server.on('error', (error) => {
      console.error('Server error:', error);
    });

    this.connectionManager.startPingInterval(this.vimClient, this.claudeClient);
  }

  handleMessage(ws, data) {
    const { type, id, method } = data;

    console.error('handleMessage: ', data);
    // Handle MCP protocol messages
    if (method === 'initialize') {
      this.handleInitialize(ws, data);
      return;
    }
    if (method === 'notifications/initialized') {
      this.handleNotificationsInitialized(ws, data);
      return;
    }
    if (method === 'tools/list') {
      this.handleToolsList(ws, data);
      return;
    }
    if (method === 'tools/call') {
      this.handleToolsCall(ws, data);
      return;
    }
    if (method === 'prompts/list') {
      this.handlePromptsList(ws, data);
      return;
    }
    if (method === 'resources/list') {
      this.handleResourcesList(ws, data);
      return;
    }
    const skipMethods = [
      'notifications/cancelled',
      'resources/list',
      'ide_connected',
    ];
    if (skipMethods.includes(method)) {
      return;
    }

    // return;
    switch (type) {
      case 'identify':
        this.handleIdentify(ws, data);
        break;
      case 'diff_request':
        this.handleDiffRequest(ws, data);
        break;
      case 'diff_response':
        this.handleDiffResponse(ws, data);
        break;
      case 'ping':
        this.handlePing(ws, data);
        break;
      default:
        this.sendError(ws, id, `Unknown message type: ${type}`, 'UNKNOWN_TYPE');
    }
  }

  handleInitialize(ws, data) {
    console.log('Received MCP initialize message');
    
    const result = {
      "protocolVersion": "2025-06-18",
      "capabilities": {
        "logging": {},
        "prompts": { "listChanged": true },
        "resources": { "subscribe": true, "listChanged": true },
        "tools": { "listChanged": true }
      },
      "serverInfo": {
        "name": "claudecode-vim",
        "version": "1.0.0"
      }
    };

    const response = {
      jsonrpc: "2.0",
      id: data.id,
      result,
    };
    
    ws.send(JSON.stringify(response));
  }

  handleNotificationsInitialized(ws, data) {
    console.log('Received notifications/initialized message');
    // Empty method as requested
  }

  handleToolsList(ws, data) {
    console.log('Received tools/list message');
    const response = {
      jsonrpc: "2.0",
      id: data.id,
      result: {
        tools: [
          {
            name: HelloEijiTool.name,
            description: HelloEijiTool.description,
            inputSchema: HelloEijiTool.inputSchema,
          }
        ],
      },
    };
    
    ws.send(JSON.stringify(response));
  }

  handleToolsCall(ws, data) {
    console.error('Received tools/call message');
    
    // Check if Vim client is connected
    if (this.vimClient) {
      // Send command to Vim client to execute "edit ./hoge.md"
      this.vimClient.send(JSON.stringify({
        type: 'execute_command',
        command: 'edit ./hoge.md',
        id: data.id
      }));
    }
    
    const response = {
      jsonrpc: "2.0",
      id: data.id,
      result: {
        content: [
          {
            type: "text",
            text: "Executed edit ./hoge.md command in Vim"
          }
        ]
      },
    };
    
    ws.send(JSON.stringify(response));
  }

  handlePromptsList(ws, data) {
    console.log('Received prompts/list message');
    const response = {
      jsonrpc: "2.0",
      id: data.id,
      result: {
        prompts: [],
      },
    };
    
    ws.send(JSON.stringify(response));
  }

  handleResourcesList(ws, data) {
    console.log('Received resources/list message');
    const response = {
      jsonrpc: "2.0",
      id: data.id,
      result: {
        resources: [],
      },
    };
    
    ws.send(JSON.stringify(response));
  }

  handleIdentify(ws, data) {
    const { client_type } = data;
    
    console.error('handleIdentify: ', data);
    if (client_type === 'vim') {
      this.vimClient = ws;
      console.error('Vim client identified');
    } else if (client_type === 'claude') {
      this.claudeClient = ws;
      console.log('Claude client identified');
    } else {
      this.sendError(ws, data.id, `Unknown client type: ${client_type}`, 'UNKNOWN_CLIENT');
      return;
    }

    ws.send(JSON.stringify({
      type: 'identify_response',
      id: data.id,
      status: 'success'
    }));
  }

  handleDiffRequest(ws, data) {
    if (!this.vimClient) {
      this.sendError(ws, data.id, 'Vim client not connected', 'VIM_NOT_CONNECTED');
      return;
    }

    try {
      const diffData = this.diffHandler.processDiffRequest(data);
      
      this.vimClient.send(JSON.stringify({
        type: 'show_diff',
        id: data.id,
        file_path: data.file_path,
        temp_original: diffData.tempOriginal,
        temp_modified: diffData.tempModified
      }));
    } catch (error) {
      console.error('Error processing diff request:', error);
      this.sendError(ws, data.id, 'Failed to process diff request', 'DIFF_PROCESSING_ERROR');
    }
  }

  handleDiffResponse(ws, data) {
    if (!this.claudeClient) {
      console.log('Claude client not connected, cannot send diff result');
      return;
    }

    this.claudeClient.send(JSON.stringify({
      type: 'diff_result',
      id: data.id,
      result: data.action === 'accept' ? 'accepted' : 'rejected'
    }));

    this.diffHandler.cleanup(data.id);
  }

  handlePing(ws, data) {
    ws.send(JSON.stringify({
      type: 'pong',
      id: data.id
    }));
  }

  sendError(ws, id, message, code) {
    ws.send(JSON.stringify({
      type: 'error',
      id: id,
      message: message,
      code: code
    }));
  }

  shutdown() {
    console.log('Shutting down server...');
    
    if (this.server) {
      this.server.close();
    }
    
    this.connectionManager.cleanup();
    process.exit(0);
  }
}

const HelloEijiTool = {
  name: 'helloEiji',
  description: "Respond to this specific message hello-eiji",
  inputSchema: {
    type: "object",
    properties: {
      filePath: {
        type: "string",
        description: "Path to the file to open",
      },

    }
  },
  handler: (p) => {
    console.error("printing tool params", p);
  },
};

const server = new MCPServer();

process.on('SIGINT', () => {
  console.log('\nReceived SIGINT, shutting down gracefully...');
  server.shutdown();
});

process.on('SIGTERM', () => {
  console.log('\nReceived SIGTERM, shutting down gracefully...');
  server.shutdown();
});

server.start();
