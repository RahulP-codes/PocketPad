import asyncio
import websockets
import json
from mouse_controller import MouseController

# Create mouse controller
mouse = MouseController()

async def handle_client(websocket, path):
    print("📱 Client connected!")
    try:
        async for message in websocket:
            data = json.loads(message)
            print(f"Received: {data}")
            
            # TEMPORARILY COMMENT OUT MOUSE CONTROL FOR WEB TEST
            # if data['type'] == 'move':
            #     mouse.move_to(data['x'], data['y'])
            # elif data['type'] == 'down':
            #     mouse.press('left')
            # elif data['type'] == 'up':
            #     mouse.release('left')
            # elif data['type'] == 'click':
            #     mouse.click(data.get('button', 'left'))
            
            # Just print for now
            if data['type'] == 'move':
                print(f"🖱️ Would move to: ({data['x']}, {data['y']})")
            
            # Echo back
            await websocket.send(f"✅ {data['type']}")
            
    except websockets.exceptions.ConnectionClosed:
        print("📱 Client disconnected")

async def start_server():
    print("🚀 PocketPad server starting on port 8765...")
    async with websockets.serve(handle_client, "0.0.0.0", 8765):
        print("✅ Server ready! Mouse control DISABLED for web test!")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(start_server())
