import asyncio
import websockets
import json
import time

async def test_mouse_control():
    print("🔌 Connecting to server...")
    try:
        uri = "ws://localhost:8765"
        async with websockets.connect(uri) as websocket:
            print("✅ Connected! Testing mouse control...")
            
            # Test 1: Move mouse to center of screen
            message = {"type": "move", "x": 500, "y": 300}
            await websocket.send(json.dumps(message))
            response = await websocket.recv()
            print(f"📍 Moved to (500, 300): {response}")
            
            await asyncio.sleep(1)
            
            # Test 2: Move to different position
            message = {"type": "move", "x": 800, "y": 400}
            await websocket.send(json.dumps(message))
            response = await websocket.recv()
            print(f"📍 Moved to (800, 400): {response}")
            
            await asyncio.sleep(1)
            
            # Test 3: Click
            message = {"type": "click", "button": "left"}
            await websocket.send(json.dumps(message))
            response = await websocket.recv()
            print(f"🖱️ Clicked: {response}")
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    asyncio.run(test_mouse_control())