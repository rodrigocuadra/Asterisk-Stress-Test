from typing import List
import websockets

class WebSocketManager:
    def __init__(self):
        self.active_connections: List[websockets.WebSocketServerProtocol] = []

    async def connect(self, ws: websockets.WebSocketServerProtocol):
        self.active_connections.append(ws)
        print(f"New WebSocket connection added. Total connections: {len(self.active_connections)}")

    async def disconnect(self, ws: websockets.WebSocketServerProtocol):
        self.active_connections.remove(ws)
        print(f"WebSocket connection removed. Total connections: {len(self.active_connections)}")

    async def broadcast(self, message: dict):
        if not self.active_connections:
            print("No active WebSocket connections to broadcast to")
            return
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
                print(f"Message broadcasted to connection: {message}")
            except Exception as e:
                print(f"Failed to send message to a connection: {e}")

manager = WebSocketManager()
