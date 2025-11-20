import asyncio
import websockets
import json
from mouse_controller_ctypes import MouseController
from broadcast import start_broadcast

mouse = MouseController()
current_x, current_y = mouse.position
click_counter = 0

async def handle_client(websocket, path):
    print("📱 Client connected!")
    global current_x, current_y, click_counter
    last_message_time = asyncio.get_event_loop().time()
    
    async def check_connection():
        nonlocal last_message_time
        try:
            while True:
                await asyncio.sleep(30)
                current_time = asyncio.get_event_loop().time()
                if current_time - last_message_time > 60:
                    print("❌ No activity for 60 seconds, closing connection")
                    await websocket.close()
                    break
        except Exception as e:
            print(f"❌ Connection check failed: {e}")
            return
    

    monitor_task = asyncio.create_task(check_connection())
    
    try:
        async for message in websocket:
            data = json.loads(message)
            
            last_message_time = asyncio.get_event_loop().time()
            
            if data.get('type') == 'keepalive':
                await websocket.send("✅ keepalive_ok")
                print("📡 Keepalive received")
                continue
            

            if data.get('type') == 'connection_test':
                await websocket.send("✅ connection_confirmed")
                print("🔍 Connection test confirmed")
                continue
            

            if data.get('type') == 'health_check':
                await websocket.send("✅ health_ok")
                continue
            
            print(f"Received: {data}")
            

            if data['type'] == 'move':

                mouse.move_to(data['x'], data['y'])
                current_x, current_y = mouse.position
                print(f"🖱️ Moved to: ({data['x']}, {data['y']})")
            elif data['type'] == 'move_relative':
                mouse.move_relative(data['deltaX'], data['deltaY'])
                current_x, current_y = mouse.position
                print(f"🖱️ 1-finger move+click: delta({data['deltaX']}, {data['deltaY']}) -> ({current_x}, {current_y})")
            elif data['type'] == 'hover_move':
                mouse.move_relative(data['deltaX'], data['deltaY'])
                current_x, current_y = mouse.position
                print(f"🖱️ 2-finger hover: delta({data['deltaX']}, {data['deltaY']}) -> ({current_x}, {current_y})")
            elif data['type'] == 'down':
                current_x, current_y = mouse.position
                mouse.press('left')
                print("🖱️ Mouse down (1-finger click ON)")
            elif data['type'] == 'up':
                mouse.release('left')
                print("🖱️ Mouse up (1-finger click OFF)")
            elif data['type'] == 'click':
                mouse.click(data.get('button', 'left'))
                print("🖱️ Click")
            

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
    start_broadcast()
    print("📡 Broadcasting server presence...")
    
    async with websockets.serve(
        handle_client, 
        "0.0.0.0", 
        8765,
        ping_interval=None,
        ping_timeout=None,
        close_timeout=10,
        max_size=None,
        max_queue=None
    ):
        print("✅ Server ready! 1-finger=click+move, 2-finger=hover only 🖱️")
        print("📡 Keepalive enabled (30s ping interval)")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(start_server())
