$DeviceIP = ""
$uri = "https://$DeviceIP/livigent/setup/localhost/interceptionRules/"
$username = ""
$password = ""

# Get cookie
$cookie = ((Invoke-WebRequest -Method Get -Uri "https://$DeviceIP/livigent/" -SkipCertificateCheck).Headers.'Set-Cookie' -split ";")[0]

# Login using cookie to authorize cookie
Invoke-RestMethod -Method Post -Uri "https://$DeviceIP/livigent/login" -Body @{"username" = $username; "password" = $password} -SkipCertificateCheck -Headers @{"Cookie" = $cookie}

Function read-interception {
    param(
        [parameter(Mandatory)]
        $Cookie,
        [parameter(Mandatory)]
        $uri,
        $depth = 0
    )

    # Interception rules
    $Interception = Invoke-RestMethod -Uri $uri -SkipCertificateCheck -Headers @{"Cookie" = $cookie}

    $s = [System.Text.RegularExpressions.RegexOptions]::Singleline

    $pages = [regex]::matches($Interception, '(?<=").+page=.+(?=")')

    $results = [regex]::Match($Interception, "<tbody>.+<\/tbody>",$s)

    $rows = [regex]::matches($results,"<tr>.*?<\/tr>",$s)

    $arrayList = [System.Collections.ArrayList]@()

    $rows | ForEach-Object {
        $options = [regex]::matches($_,'<td.*?>.*?<\/td>',$s)

        $hash = [ordered]@{}

        for ($i = 1 ; $i -lt $options.Count; $i++) {
            switch ($i) {
                1   {$hash["Source"]          = [regex]::Match($options[$i],"(?<=>).+(?=<)").value.trim()}
                2   {$hash["sPorts"]          = [regex]::Match($options[$i],"(?<=>).+(?=<)").value.trim()}
                3   {$hash["Destination"]     = [regex]::Match($options[$i],"(?<=>).+(?=<)").value.trim()}
                4   {$hash["dPorts"]          = [regex]::Match($options[$i],"(?<=>).+(?=<)").value.trim()}
                5   {$hash["Protocols"]       = [regex]::Match($options[$i],"(?<=>).+(?=<)").value.trim()}
                6   {$hash["Action"]          = [regex]::Match($options[$i],"(?<=>).+(?=<)").value.trim()}
                7   {$hash["Comment"]         = [regex]::Match($options[$i],'(?<=span title=").+?(?="|\n)').value}
                8   {$hash["Edit"]            = [regex]::Match($options[$i],'(?<=href=").+?(?=")').value.replace("setup#localhost", "setup/localhost").trim()}
                9   {$hash["Remove"]          = [regex]::Match($options[$i],"(?<=')htt.+?(?=')").value.replace("setup#localhost", "setup/localhost").trim()}
            }
        }
        [void]$arraylist.add([pscustomobject]$hash)
    }
    
    if ($depth -eq 0) {
        $looped = $pages[1..($pages.Count-1)] | ForEach-Object {
            $current = [string]$_ -replace "setup#localhost", "setup/localhost"
            read-interception -Cookie $cookie -uri $current -depth 1
        }
    
        $looped | ForEach-Object {
            [void]$arrayList.add($_)
        }
    }

    $arrayList | where-object {![string]::IsNullOrEmpty($_)}
}

Function Invoke-LivigentURI {
    param(
        [parameter(Mandatory)]
        $uri,
        $cookie = $cookie
    )
    Invoke-RestMethod -Headers @{"Cookie" = $cookie} -Uri $uri -SkipCertificateCheck
}
