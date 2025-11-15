# Message types that mobile app will send
TOUCH_MOVE = "move"
TOUCH_DOWN = "down" 
TOUCH_UP = "up"
CLICK = "click"

# Example message formats
"""
Touch move: {"type": "move", "x": 100, "y": 200}
Touch down: {"type": "down", "x": 100, "y": 200}
Touch up: {"type": "up", "x": 100, "y": 200}
Click: {"type": "click", "button": "left"}
"""