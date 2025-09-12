-- Simple Safari Private Browsing Detection Test
-- Run this in Script Editor to test every second

repeat
    tell application "System Events"
        tell process "Safari"
            try
                set theMenuBar to menu bar 1
                set theWindowMenu to menu "Window" of theMenuBar
                return (menu item "Move Tab to New Private Window" of theWindowMenu) exists
            on error
                return false
            end try
        end tell
    end tell
    
    delay 1
end repeat