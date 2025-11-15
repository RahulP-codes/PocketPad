from pynput.mouse import Controller, Button

class MouseController:
    def __init__(self):
        self.mouse = Controller()
    
    def move_to(self, x, y):
        """Move mouse to absolute position"""
        self.mouse.position = (x, y)
    
    def click(self, button='left'):
        """Click mouse button"""
        if button == 'left':
            self.mouse.click(Button.left)
        elif button == 'right':
            self.mouse.click(Button.right)
    
    def press(self, button='left'):
        """Press and hold mouse button"""
        if button == 'left':
            self.mouse.press(Button.left)
    
    def release(self, button='left'):
        """Release mouse button"""
        if button == 'left':
            self.mouse.release(Button.left)
