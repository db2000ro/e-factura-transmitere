$script = [ScriptBlock]::Create("Using module `"$PSScriptRoot/Proxy.psm1`"")
. $script

$Options = & $PSScriptRoot/Init.ps1 -ResetConfig 0

if ($Options.ResetConfig -eq 1) {
    Read-Host "Configurare terminata. Puteti reporni aplicatia.`nApasati ENTER prentu inchidere"
    exit
}

[Proxy]::init($Options.Config.Mod, $Options.Config.Auth, $Options.Config.CertThumbprint);

$PromtText = "Selectati modul de lucru`n    1. Upload xml-uri E-Factura din directorul data\upload`n    2. Decarcare zip-uri E (erori) T (trimise) P (primite) R (mesaj partener)`n    3. Descarcare lista mesaje E-Factura`n    9. Reconfigurare`n    sau ENTER pentru inchidere`n"
$Response = (Read-Host -Prompt $PromtText)

if ($Response -eq "") {
    exit
}
elseif ($Response -eq "1") {
    $date = (Get-Date).ToString("yyyyMMddHHmm")

    $status = @{
        ok = 0
        err = 0
    }

    foreach ($file in (Get-ChildItem -Path ($Options.DataDir + "upload/*") -Include *.xml)) {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $fileExtension = [System.IO.Path]::GetExtension($file)
        $log = [PSCustomObject]@{
            date = $date
            invoice = "$($fileName)$($fileExtension)"
            status = ""
            index_incarcare = ""
            message = ""
        }
        try {
            $XMLString = Get-Content -Path $file
            $Response = [Proxy]::Upload($Options.Config.CifEmitent, $XMLString, $Options.Config.Standard)
            try {
                $ResponseXml = [xml] $Response.Content

                if ($ResponseXml.header.index_incarcare -eq $null) {
                    if ($ResponseXml.header.Errors.errorMessage -ne $null) {
                        throw $ResponseXml.header.Errors.errorMessage
                    }
                    throw "Nu s-a putut obtine indexul de incarcare."
                }

                $log.date = $ResponseXml.header.dateResponse
                $log.status = "ok"
                $log.index_incarcare = $ResponseXml.header.index_incarcare
            }
            catch {
                throw "$($_)"
            }

            Move-Item -Path $file -Destination ("$($Options.DataDir)upload/ok/$($date)-$($fileName)$($fileExtension)")
            Set-Content -Path ("$($Options.DataDir)upload/ok/$($date)-$($fileName)-R$($fileExtension)") -Value $ResponseXml.OuterXml
        }
        catch {
            $log.status = "err"
            $log.message = "$($_)"
            Move-Item -Path $file -Destination ("$($Options.DataDir)upload/err/$($date)-$($fileName)$($fileExtension)")
            if ($ResponseXml -ne $null) {
                Set-Content -Path ("$($Options.DataDir)upload/err/$($date)-$($fileName)-R-err.xml") -Value $ResponseXml.OuterXml
            }
            elseif ($Response.Content -ne $null) {
                Set-Content -Path ("$($Options.DataDir)upload/err/$($date)-$($fileName)-R-err.txt") -Value $Response.Content
            }
            else {
                Set-Content -Path ("$($Options.DataDir)upload/err/$($date)-$($fileName)-R-err.txt") -Value $log.message
            }
        }
        $log | Export-Csv -NoTypeInformation -Append -Force "$($Options.DataDir)log/$($date.substring(0, 6))-upload.csv"
        if ($log.status -eq "ok") {
            ++$status.ok
        }
        else {
            ++$status.err
        }
    }
    Read-Host "$($status.ok) fisiere au fost incarcate cu succes; $($status.err) erori.`nApasati ENTER prentu inchidere"
    exit
}
elseif (($Response -eq "2") -or ($Response -eq "3")) {
    $date = (Get-Date).ToString("yyyyMMddHHmm")
    $SfarsitPerioada = [Proxy]::SfarsitPerioada($Options.Config.MinuteAsteptareMesaje)
    $InceputPerioada = [Proxy]::InceputPerioada($Options.Config.NumarZileMesaje, $SfarsitPerioada)
    try
    {
        $status = @{
            E = @{
                ok = 0
                err = 0
            }
            T = @{
                ok = 0
                err = 0
            }
            P = @{
                ok = 0
                err = 0
            }
            R = @{
                ok = 0
                err = 0
            }
        }
        foreach ($type in "E", "T", "P", "R") {
            $totalPagini = 1
            $pagina = 1
            while ($pagina -le $totalPagini) {
                $Response = [Proxy]::DownloadMessageList($InceputPerioada, $SfarsitPerioada, $Options.Config.CifEmitent, $pagina, $type)
                $ResponseJson = ($Response.Content | ConvertFrom-Json)
                $totalPagini = $ResponseJson.numar_total_pagini
                if ($Response -eq "2") {
                    foreach ($mesaj in $ResponseJson.mesaje) {
                        $log = [PSCustomObject]@{
                            date = $mesaj.data_creare
                            cif = $mesaj.cif
                            id_solicitare = $mesaj.id_solicitare
                            tip = $type
                            id = $mesaj.id
                            status = ""
                            message = ""
                        }
                        $filePath = "$($Options.DataDir)download/$($type)/$($mesaj.id).zip"
                        if (!(Test-Path -Path $filePath)) {
                            try {
                                $DownloadResponse = [Proxy]::Download($mesaj.id, $filePath)
                                $log.status = "ok"
                                ++$status.$type.ok
                            }
                            catch {
                                $log.status = "err"
                                $log.message = $_.ToString
                                ++$status.$type.err
                            }
                            $log | Export-Csv -NoTypeInformation -Append -Force "$($Options.DataDir)log/$($date.substring(0, 6))-download.csv"
                        }
                    }
                }
                elseif ($Response -eq "3") {
                    Set-Content -Path "$($Options.DataDir)download/$($date)-$($type)-p$($pagina).json" -Value $Response.Content
                }
                ++$pagina
            }
        }
    } catch {
        $e = [PSCustomObject]@{
            date = $date
            message = $_.ToString
        }
        $e | Export-Csv -NoTypeInformation -Append -Force "$($Options.DataDir)log/$($date.substring(0, 6))-errors.csv"
        "Eroare: $($_.ToString)"
    }
    $status.Keys | ForEach-Object {
        "$($_) $($status[$_].ok) ok $($status[$_].err) err"
    }
    Read-Host "Apasati ENTER prentu inchidere"
    exit
}
elseif ($Response -eq "9") {
    $Options = & $PSScriptRoot/Init.ps1 -ResetConfig 1
    exit
}
else {
    Read-Host "Selectie invalida`nApasati ENTER prentu inchidere"
    exit
}
