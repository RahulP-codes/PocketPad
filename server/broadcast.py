import socket
import time
import threading

def broadcast_server_ip():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    
    while True:
        try:
            message = b"POCKETPAD_SERVER:8765"
            sock.sendto(message, ('<broadcast>', 8766))
            time.sleep(2)
        except Exception as e:
            print(f"Broadcast error: {e}")
            time.sleep(5)

def start_broadcast():
    thread = threading.Thread(target=broadcast_server_ip, daemon=True)
    thread.start()
