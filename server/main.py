import asyncio
import websockets
import json
from mouse_controller import MouseController

# Create mouse controller
mouse = MouseController()

# Track current cursor position
current_x, current_y = mouse.mouse.position

async def handle_client(websocket, path):
    print("📱 Client connected!")
    
    # Declare global variables at the start
    global current_x, current_y
    
    # Simple keepalive without WebSocket ping/pong
    last_message_time = asyncio.get_event_loop().time()
    
    async def check_connection():
        nonlocal last_message_time
        try:
            while True:
                await asyncio.sleep(30)  # Check every 30 seconds
                current_time = asyncio.get_event_loop().time()
                if current_time - last_message_time > 60:  # No message for 60 seconds
                    print("❌ No activity for 60 seconds, closing connection")
                    await websocket.close()
                    break
        except Exception as e:
            print(f"❌ Connection check failed: {e}")
            return
    
    # Start connection monitoring
    monitor_task = asyncio.create_task(check_connection())
    
    try:
        async for message in websocket:
            data = json.loads(message)
            
            # Update last message time for any message
            last_message_time = asyncio.get_event_loop().time()
            
            # Handle keepalive
            if data.get('type') == 'keepalive':
                await websocket.send("✅ keepalive_ok")
                print("📡 Keepalive received")
                continue
            
            # Handle connection test
            if data.get('type') == 'connection_test':
                await websocket.send("✅ connection_confirmed")
                print("🔍 Connection test confirmed")
                continue
            
            # Handle health check
            if data.get('type') == 'health_check':
                await websocket.send("✅ health_ok")
                continue
            
            print(f"Received: {data}")
            
            # Handle mouse control - RELATIVE MOVEMENT
            if data['type'] == 'move':
                # Absolute movement (old method)
                mouse.move_to(data['x'], data['y'])
                current_x, current_y = data['x'], data['y']
                print(f"🖱️ Moved to: ({data['x']}, {data['y']})")
            elif data['type'] == 'move_relative':
                # Relative movement (new method)
                current_x += data['deltaX']
                current_y += data['deltaY']
                mouse.move_to(current_x, current_y)
                print(f"🖱️ Relative move: delta({data['deltaX']}, {data['deltaY']}) -> ({current_x}, {current_y})")
            elif data['type'] == 'down':
                # mouse.press('left')  # DISABLED
                print("🖱️ Mouse down (disabled)")
            elif data['type'] == 'up':
                # mouse.release('left')  # DISABLED
                print("🖱️ Mouse up (disabled)")
            elif data['type'] == 'click':
                # mouse.click(data.get('button', 'left'))  # DISABLED
                print("🖱️ Click (disabled)")
            
            # Echo back
            await websocket.send(f"✅ {data['type']}")
            
    except websockets.exceptions.ConnectionClosed:
        print("📱 Client disconnected")
    except Exception as e:
        print(f"❌ Connection error: {e}")
    finally:
        monitor_task.cancel()
        print("🔌 Connection cleanup completed")

async def start_server():
    print("🚀 PocketPad server starting on port 8765...")
    
    # Server with disabled WebSocket ping/pong to avoid timeout issues
    async with websockets.serve(
        handle_client, 
        "0.0.0.0", 
        8765,
        ping_interval=None,  # Disable automatic ping
        ping_timeout=None,   # Disable ping timeout
        close_timeout=10,    # Wait 10 seconds before force close
        max_size=None,       # No message size limit
        max_queue=None       # No queue size limit
    ):
        print("✅ Server ready! RELATIVE mouse movement (clicks disabled) 🖱️")
        print("📡 Keepalive enabled (30s ping interval)")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(start_server())
