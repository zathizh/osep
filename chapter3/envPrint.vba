Sub envPrint()
	For iCnt = 1 To 40
		ActiveDocument.Content.InsertAfter Text:= int & " " & Environ(iCnt) & vbNewLine
	Next iCnt
End Sub

Sub Document_Open()
	envPrint
End Sub

Sub AutoOpen()
	envPrint
End Sub
