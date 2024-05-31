Param(
    [int]$ResetConfig
)

$Options = [ordered]@{
    DataDir                    = $PSScriptRoot + "\..\data\";
    CfgFile                    = $PSScriptRoot + "\..\data\config.json";
    Config = [ordered]@{
        Mod                    = "test";
        Auth                   = "cert";
        Standard               = "UBL";
        CifEmitent             = "";
        CertThumbprint         = "";
        NumarZileMesaje        = 60;
        MinuteAsteptareMesaje  = 5;
    };
    ResetConfig                = $ResetConfig;
}

if (!(Test-Path $Options.DataDir)) {
    New-Item -Path $Options.DataDir -ItemType "directory" -Force
    New-Item -Path ($Options.DataDir + "download/") -ItemType "directory" -Force
    New-Item -Path ($Options.DataDir + "download/E/") -ItemType "directory" -Force
    New-Item -Path ($Options.DataDir + "download/T/") -ItemType "directory" -Force
    New-Item -Path ($Options.DataDir + "download/P/") -ItemType "directory" -Force
    New-Item -Path ($Options.DataDir + "download/R/") -ItemType "directory" -Force
    New-Item -Path ($Options.DataDir + "download/mesaje/") -ItemType "directory" -Force
    New-Item -Path ($Options.DataDir + "upload/") -ItemType "directory" -Force
    New-Item -Path ($Options.DataDir + "upload/ok/") -ItemType "directory" -Force
    New-Item -Path ($Options.DataDir + "upload/err/") -ItemType "directory" -Force
    New-Item -Path ($Options.DataDir + "log/") -ItemType "directory" -Force
}

if (!(Test-Path $Options.CfgFile)) {
    Set-Content -Path $Options.CfgFile -Value ($Options.Config | ConvertTo-Json)
    $Options.ResetConfig = 1
}

$Options.Config = Get-Content -Raw $Options.CfgFile | ConvertFrom-Json

if (($Options.ResetConfig -eq 1) -or ($Options.Config.CertThumbprint -eq "") -or ($Options.Config.CifEmitent -eq "") -or ($Options.Config.Mod -notin "test", "prod")) {

    $Certificates = Get-ChildItem Cert:\CurrentUser\My -Recurse
    if ($Certificates.length -eq 0) {
        "Nu au fost gasite certificate"
        exit
    }
    $PromtText = "Selectati id-ul certificatului (intre 1 si " + $Certificates.length.ToString() + ")`n"
    for ($i = 0; $i -lt $Certificates.length; ++$i) {
        $PromtText += "    " + ($i + 1).ToString() +". " + $Certificates[$i].subject + " valabil pana la " + $Certificates[$i].NotAfter + "`n"
        if (($Certificates[$i].Thumbprint -eq $Thumbprint) -and ($Thumbprint -ne "")) {
            $Certificate = $Certificates[$i]
        }
    }
    $Response = (Read-Host -Prompt $PromtText)
    if ($Response -NotMatch "^[0-9]+$") {
        "Id certificat invalid"
        exit
    }
    if (([int]$Response -lt 1) -or ([int]$Response -gt $Certificates.length)) {
        "Id certificat invalid"
        exit
    }
    $Options.Config.CertThumbprint = $Certificates[[int]$Response - 1].Thumbprint

    $Response = (Read-Host -Prompt "Introduceti cif-ul societatii emitente (numai caractere numerice)")
    if (($Response -NotMatch "^[0-9]+$")) {
        "Cif invalid"
        exit
    }
    $Options.Config.CifEmitent = $Response

    $Response = (Read-Host -Prompt ("Selectati numarul de zile pentru care doriti descarcarea mesajelor (implicit " + ([string]$Options.Config.NumarZileMesaje) + ")"))

    if ($Response -Match "^[0-9]+$") {
        $Options.Config.NumarZileMesaje = [int]$Response
    }

    $Response = (Read-Host -Prompt ("Selectati numarul de minute de scazut din timpul actual pentru descarcarea mesajelor (implicit " + ([string]$Options.Config.MinuteAsteptareMesaje) + "; este util pentru evitarea erorilor in cazul in care ceasul calculatorului este inaintea celui al server-ului ANAF)"))

    if ($Response -Match "^[0-9]+$") {
        $Options.Config.MinuteAsteptareMesaje = [int]$Response
    }
    Set-Content -Path $Options.CfgFile -Value ($Options.Config | ConvertTo-Json)

    $Response = (Read-Host -Prompt ("Selectati modul de lucru (implicit " + ([string]$Options.Config.Mod) + ")`n    1. test`n    2. prod`n"))

    if ($Response -Match "^[1-2]{1}$") {
        $Options.Config.Mod = ("test", "prod")[([int]$Response) - 1]
    }

    $Response = (Read-Host -Prompt ("Selectati modul de autentificare (implicit " + ([string]$Options.Config.Auth) + ")`n    1. cert`n    2. OAuth`n"))

    if ($Response -Match "^[1-2]{1}$") {
        $Options.Config.Auth = ("cert", "OAuth")[([int]$Response) - 1]
    }
    Set-Content -Path $Options.CfgFile -Value ($Options.Config | ConvertTo-Json)
}

return $Options