# Message types that mobile app will send
TOUCH_MOVE = "move"
TOUCH_DOWN = "down" 
TOUCH_UP = "up"
CLICK = "click"
MOVE_RELATIVE = "move_relative"  # 1-finger with click
HOVER_MOVE = "hover_move"        # 2-finger hover only

# Example message formats
"""
Touch move: {"type": "move", "x": 100, "y": 200}
Touch down: {"type": "down", "x": 100, "y": 200}
Touch up: {"type": "up", "x": 100, "y": 200}
Click: {"type": "click", "button": "left"}
1-finger move: {"type": "move_relative", "deltaX": 10, "deltaY": 5}
2-finger hover: {"type": "hover_move", "deltaX": 10, "deltaY": 5}
"""