# Charmbracelet VHS tape for agyr demo
# Output paths
Output docs/assets/demo.gif
Output docs/assets/demo.mp4

# Terminal window styling
Set Shell "bash"
Set FontSize 14
Set FontFamily "JetBrains Mono"
Set Width 1100
Set Height 600
Set Theme "Catppuccin Mocha"
Set WindowBar "Colorful"
Set WindowBarSize 40
Set Padding 20

# Demo agyr list (shows multi-account quota status table)
Type "agyr list"
Sleep 500ms
Enter
Sleep 4s

# Demo agyr help (shows command suite overview)
Type "agyr help"
Sleep 500ms
Enter
Sleep 4s
