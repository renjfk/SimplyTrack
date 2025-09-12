-- Safari Private Browsing Detection Test Script
-- Runs every second to monitor menu item existence

on run
    repeat
        try
            tell application "System Events"
                tell process "Safari"
                    try
                        set theMenuBar to menu bar 1
                        set theWindowMenu to menu "Window" of theMenuBar
                        set menuItemExists to (menu item "Move Tab to New Private Window" of theWindowMenu) exists
                        
                        -- Log the result with timestamp
                        set currentTime to (current date) as string
                        set logMessage to currentTime & " - Menu item exists: " & menuItemExists
                        
                        -- Display result (you can comment this out if too verbose)
                        display notification logMessage with title "Safari Private Test"
                        
                        -- Also log to system log
                        do shell script "echo '" & logMessage & "' >> /tmp/safari_private_test.log"
                        
                    on error theError
                        set errorMessage to (current date) as string & " - Error: " & theError
                        display notification errorMessage with title "Safari Private Test Error"
                        do shell script "echo '" & errorMessage & "' >> /tmp/safari_private_test.log"
                    end try
                end tell
            end tell
        on error outerError
            set errorMessage to (current date) as string & " - Outer Error: " & outerError
            do shell script "echo '" & errorMessage & "' >> /tmp/safari_private_test.log"
        end try
        
        -- Wait 1 second before next check
        delay 1
    end repeat
end run