from fastapi import WebSocket

class WebSocketManager:
    def __init__(self):
        self.active = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active.append(websocket)

    async def disconnect(self, websocket: WebSocket):
        if websocket in self.active:
            self.active.remove(websocket)

    async def broadcast(self, message: dict):
        for ws in self.active:
            try:
                await ws.send_json(message)
            except:
                pass

# Este objeto es el que se importa en main.py
manager = WebSocketManager()
