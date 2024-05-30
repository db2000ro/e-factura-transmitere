class Proxy {
    static [string] $Mod;
    static [string] $Auth;
    static [string] $AuthData;
    static [object] $Urls = @{
        prod = @{
            OAuth = @{
                upload = 'https://api.anaf.ro/prod/FCTEL/rest/upload';
                listaMesaje = 'https://api.anaf.ro/prod/FCTEL/rest/listaMesajeFactura';
                listaMesajePaginatie = 'https://api.anaf.ro/prod/FCTEL/rest/listaMesajePaginatieFactura';
                stareMesaj = 'https://api.anaf.ro/prod/FCTEL/rest/stareMesaj';
                descarcare = 'https://api.anaf.ro/prod/FCTEL/rest/descarcare';
            };
            cert = @{
                upload = 'https://webserviceapl.anaf.ro/prod/FCTEL/rest/upload';
                listaMesaje = 'https://webserviceapl.anaf.ro/prod/FCTEL/rest/listaMesajeFactura';
                listaMesajePaginatie = 'https://webserviceapl.anaf.ro/prod/FCTEL/rest/listaMesajePaginatieFactura';
                stareMesaj = 'https://webserviceapl.anaf.ro/prod/FCTEL/rest/stareMesaj';
                descarcare = 'https://webserviceapl.anaf.ro/prod/FCTEL/rest/descarcare';
            };
        };
        test = @{
            OAuth = @{
                upload = 'https://api.anaf.ro/test/FCTEL/rest/upload';
                listaMesaje = 'https://api.anaf.ro/test/FCTEL/rest/listaMesajeFactura';
                listaMesajePaginatie = 'https://api.anaf.ro/test/FCTEL/rest/listaMesajePaginatieFactura';
                stareMesaj = 'https://api.anaf.ro/test/FCTEL/rest/stareMesaj';
                descarcare = 'https://api.anaf.ro/test/FCTEL/rest/descarcare';
            };
            cert = @{
                upload = 'https://webserviceapl.anaf.ro/test/FCTEL/rest/upload';
                listaMesaje = 'https://webserviceapl.anaf.ro/test/FCTEL/rest/listaMesajeFactura';
                listaMesajePaginatie = 'https://webserviceapl.anaf.ro/test/FCTEL/rest/listaMesajePaginatieFactura';
                stareMesaj = 'https://webserviceapl.anaf.ro/test/FCTEL/rest/stareMesaj';
                descarcare = 'https://webserviceapl.anaf.ro/test/FCTEL/rest/descarcare';
            };
        };
    };

    static [void] init([string]$Mod, [string]$Auth, [string]$AuthData) {
        [Proxy]::validateInit([string]$Mod, [string]$Auth)
        [Proxy]::Mod = $Mod
        [Proxy]::Auth = $Auth
        [Proxy]::AuthData = $AuthData
    }

    static [void] validateInit([string]$Mod, [string]$Auth) {
        if ($Mod -notin "test", "prod") {
            throw "Mod invalid $($Mod). Folositi test sau prod."
        }
        if ($Auth -notin "OAuth", "cert") {
            Throw "Metoda de autentificare invalida $($Auth). Folositi OAuth sau cert."
        }
    }

    static [object] GetUrls() {
        [Proxy]::validateInit([Proxy]::Mod, [Proxy]::Auth)
        return [Proxy]::Urls.([Proxy]::Mod).([Proxy]::Auth)
    }

    static [string] AddQueryString([string]$Uri, [object]$Parameters) {

        $Qs = $Parameters.Keys | ForEach-Object {
            [System.Net.WebUtility]::UrlEncode($_)+"="+[System.Net.WebUtility]::UrlEncode($($Parameters[$_]))
        }
        return $Uri + "?" + ($Qs -join "&")
    }

    static [object] Upload([int]$cif, [string]$XMLString, [string]$standard) {

        $Uri = [Proxy]::AddQueryString(([Proxy]::GetUrls()).upload, ([ordered]@{
            standard   = $standard
            cif        = $cif
        }))
        if ([Proxy]::Auth -eq "cert") {
            return Invoke-WebRequest -Uri $Uri -ContentType "text/plain" -Method Post -Body $XMLString -CertificateThumbprint ([Proxy]::AuthData)
        }
        else {
            Throw "Metoda de autentificare $([Proxy]::Auth) nu este implementata."
        }
    }

    static [object] DownloadMessageList([int64]$startTime, [int64]$endTime, [int]$cif, [int]$pagina, [string]$filtru) {

        $Parameters = @{
            startTime  = $startTime
            endTime    = $endTime
            cif        = $cif
            pagina     = $pagina
        }
        
        if ($filtru -in "E", "T", "P", "R") {
            $Parameters.filtru = $filtru
        }
        if ([Proxy]::Auth -eq "cert") {
            return Invoke-WebRequest -Uri (([Proxy]::GetUrls()).listaMesajePaginatie) -Method Get -Body $Parameters -CertificateThumbprint ([Proxy]::AuthData)
        }
        else {
            Throw "Metoda de autentificare $([Proxy]::Auth) nu este implementata."
        }
    }

    static [object] Download([string]$id, [string]$filePath) {

        $Parameters = @{
            id  = $id
        }

        if ([Proxy]::Auth -eq "cert") {
            return Invoke-WebRequest -Uri (([Proxy]::GetUrls()).descarcare) -Method Get -Body $Parameters -OutFile $filePath -PassThru -CertificateThumbprint ([Proxy]::AuthData)
        }
        else {
            Throw "Metoda de autentificare $([Proxy]::Auth) nu este implementata."
        }
    }

    static [int64] SfarsitPerioada([int] $MinuteAsteptare) {
        return [int64](((New-TimeSpan -Start (New-Object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)) -End ([DateTime]::UtcNow)).TotalSeconds) * 1000 - ($MinuteAsteptare * 60 * 1000))
    }

    static [int64] InceputPerioada([int] $NumarZile, [int64] $SfarsitPerioada) {
        return [int64]($SfarsitPerioada - $NumarZile * 24 * 60 * 60 * 1000)
    }
}
