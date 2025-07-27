class ConnectionManager {
  constructor() {
    this.pingInterval = null;
    this.pingIntervalMs = 30000; // 30 seconds
    this.connections = new Map();
  }

  startPingInterval(vimClient, claudeClient) {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
    }

    this.pingInterval = setInterval(() => {
      this.pingClients(vimClient, claudeClient);
    }, this.pingIntervalMs);
  }

  pingClients(vimClient, claudeClient) {
    const timestamp = Date.now();
    
    if (vimClient && vimClient.readyState === 1) { // WebSocket.OPEN
      try {
        vimClient.send(JSON.stringify({
          type: 'ping',
          id: `ping_vim_${timestamp}`
        }));
      } catch (error) {
        console.error('Error pinging Vim client:', error);
      }
    }

    if (claudeClient && claudeClient.readyState === 1) { // WebSocket.OPEN
      try {
        claudeClient.send(JSON.stringify({
          type: 'ping',
          id: `ping_claude_${timestamp}`
        }));
      } catch (error) {
        console.error('Error pinging Claude client:', error);
      }
    }
  }

  registerConnection(ws, clientType) {
    const connectionId = `${clientType}_${Date.now()}`;
    this.connections.set(connectionId, {
      ws,
      clientType,
      connectedAt: Date.now(),
      lastPing: null,
      lastPong: null
    });
    return connectionId;
  }

  unregisterConnection(connectionId) {
    this.connections.delete(connectionId);
  }

  updatePongTime(connectionId) {
    const connection = this.connections.get(connectionId);
    if (connection) {
      connection.lastPong = Date.now();
    }
  }

  getConnectionStatus() {
    const status = {
      total: this.connections.size,
      vim: 0,
      claude: 0,
      connections: []
    };

    this.connections.forEach((conn, id) => {
      if (conn.clientType === 'vim') status.vim++;
      if (conn.clientType === 'claude') status.claude++;
      
      status.connections.push({
        id,
        type: conn.clientType,
        connected: conn.connectedAt,
        lastPing: conn.lastPing,
        lastPong: conn.lastPong,
        isAlive: conn.ws.readyState === 1
      });
    });

    return status;
  }

  checkConnectionHealth() {
    const now = Date.now();
    const deadConnections = [];

    this.connections.forEach((conn, id) => {
      if (conn.ws.readyState !== 1) { // Not open
        deadConnections.push(id);
      } else if (conn.lastPing && !conn.lastPong) {
        // Ping sent but no pong received
        const timeSincePing = now - conn.lastPing;
        if (timeSincePing > this.pingIntervalMs * 2) {
          console.warn(`Connection ${id} appears to be dead (no pong for ${timeSincePing}ms)`);
          deadConnections.push(id);
        }
      }
    });

    // Clean up dead connections
    deadConnections.forEach(id => {
      this.unregisterConnection(id);
    });

    return deadConnections;
  }

  cleanup() {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
    
    this.connections.clear();
  }

  isVimConnected() {
    for (const [id, conn] of this.connections) {
      if (conn.clientType === 'vim' && conn.ws.readyState === 1) {
        return true;
      }
    }
    return false;
  }

  isClaudeConnected() {
    for (const [id, conn] of this.connections) {
      if (conn.clientType === 'claude' && conn.ws.readyState === 1) {
        return true;
      }
    }
    return false;
  }
}

module.exports = { ConnectionManager };