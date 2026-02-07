# Made using https://github.com/charmbracelet/vhs

Set Width 800
Set Height 300
Output demo.gif
Set TypingSpeed 20ms
Set Shell zsh
Sleep 1000ms
Type "./gqlt merge typeDefs/*.graphql combined.graphql"
Sleep 500ms
Enter
Sleep 2000ms
Type "du -sh combined.graphql"
Enter
Sleep 3000ms
