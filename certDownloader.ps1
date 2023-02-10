$version="1.0.3"

Write-Output("Starting certDownloader vers $version")

$confFile='c:\EngScripts\certDownloader\certDownloader.ps1.conf'

$confExists=(Test-Path -Path $confFile)

if ( -Not (Test-Path -Path $confFile) )
{
   Write-Output("Errore: impossibile trovare il file di configurazione $confFile")
   Exit 2
}

### leggo il contenuto del file e salvo tutto in un associative array
$ExternalVariables = Get-Content -raw -Path $confFile | ConvertFrom-StringData

### verifo se sono impostate tutte le variabili che servono
if ($ExternalVariables.containsKey('pfxPassEnc'))
{
   $pfxPassEnc =  $ExternalVariables.pfxPassEnc
   $pfxPassClear = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($pfxPassEnc))
   $pfxPassPwsh = ConvertTo-SecureString -String "$pfxPassClear" -Force -AsPlainText
}
else
{
   Write-Output("Errore: il file di configurazione $confFile non contiene un valore per pfxPassEnc")
   Exit 2
}

if ($ExternalVariables.containsKey('CSLocation'))
{
   $CSLocation =  $ExternalVariables.CSLocation
}
else
{
   Write-Output("Errore: il file di configurazione $confFile non contiene un valore per CSLocation")
   Exit 2
}

if ($ExternalVariables.containsKey('skipThese'))
{
   $skipThese = @()
   $stringSkip = $ExternalVariables.skipThese
   $arrSkip = $stringSkip.split(',')
   foreach ($element in $arrSkip)
   {
      $skipThese += $element
   }
}
else
{
   $skipThese = @()
}

if ($ExternalVariables.containsKey('certList'))
{
   $CSLocation =  $ExternalVariables.certList
}
else
{
   Write-Output("Errore: il file di configurazione $confFile non contiene un valore per certList")
   Exit 2
}

if ($ExternalVariables.containsKey('certDepot'))
{
   $CSLocation =  $ExternalVariables.certDepot
}
else
{
   Write-Output("Errore: il file di configurazione $confFile non contiene un valore per certDepot")
   Exit 2
}

if ($ExternalVariables.containsKey('pscp'))
{
   $CSLocation =  $ExternalVariables.pscp
}
else
{
   Write-Output("Errore: il file di configurazione $confFile non contiene un valore per pscp")
   Exit 2
}

if ($ExternalVariables.containsKey('sftpUser'))
{
   $CSLocation =  $ExternalVariables.sftpUser
}
else
{
   Write-Output("Errore: il file di configurazione $confFile non contiene un valore per sftpUser")
   Exit 2
}

if ($ExternalVariables.containsKey('sftpHost'))
{
   $CSLocation =  $ExternalVariables.sftpHost
}
else
{
   Write-Output("Errore: il file di configurazione $confFile non contiene un valore per sftpHost")
   Exit 2
}

if ($ExternalVariables.containsKey('sftpCert'))
{
   $CSLocation =  $ExternalVariables.sftpCert
}
else
{
   Write-Output("Errore: il file di configurazione $confFile non contiene un valore per sftpCert")
   Exit 2
}

#### fine del caricamento valori da file

if ( -Not (Test-Path -Path $pscp) )
{
   Write-Output("Errore: impossibile trovare l'eseguibile $pscp")
   exit 1
}

if ( -Not (Test-Path -Path $certList) )
{
   Write-Output("Errore: impossibile trovare il file di lista dei certificati $certList")
   exit 2
}

if ( -Not (Test-Path -Path $sftpCert) )
{
   Write-Output("Errore: impossibile trovare il file $sftpCert")
   exit 3
}

$sftpTest=(tnc -computername $sftpHost -port 22 -InformationLevel Quiet)

if ($sftpTest -ne 'True')
{
   Write-Output("Errore: impossibile contattare il server $sftpHost su porta 22")
   exit 4
}

if ( -Not (Test-Path -Path $certDepot ) )
{
   Write-Output("Errore: non esiste la directory $certDepot")
   exit 5
}

### se arrivo qui ho sorpassato tutti i test iniziali

### metto in un oggetto arraylist il contenuto del file $certList
$certificates = Get-Content -Path $certList

foreach ( $cn in  $certificates)
{
   Write-Output("provo a scaricare : $cn")
   ##c:\EngScripts\bin\pscp.exe -r -l ${sftpUser} -i ${sftpCert} -C ${sftpHost}:/${cn} ${certDepot}"
   & "$pscp" -r -l ${sftpUser} -i ${sftpCert} -C ${sftpHost}:/${cn} ${certDepot}
   
   $certFullPath = "$certDepot" + "\" + "$cn" + "\full.pfx"
   
   ### verifico se il cn e' presente nella lista di quelli da skippare
   $skipCN = ($skipThese.Contains($cn)) 
   
   ### verifico se il cn e' tra quelli da skippare'
   if  ($skipCN -eq $false)
   {
      ### verifico se esiste un file full.pfx nel path relativo al certificato che sto lavorando
      if  ((Test-Path -Path  "$certFullPath" -PathType leaf) -and ($skipCN -eq $false) )
      {   
         Write-Output("provo ad importare : $cn")
         ### carico in un oggetto di tipo certificato i dati del file scaricato
         $myCert = Get-PfxData -FilePath $certFullPath -Password $pfxPassPwsh
         if ($myCert)
         {
            ### ricavo il thumbprint del certificato in localdepot
            $certFileThumbprint = $myCert.EndEntityCertificates.Thumbprint
            ### cerco sul certificate store di sistema un certificato con quel preciso thumbprint
            $certOnStore = Get-ChildItem -Path $CSLocation | Where-Object {$_.Thumbprint -Match "$certFileThumbprint"}
            ### se non trovo nulla importo il certificato
            if (-not ($certOnStore))
            {
               Import-PfxCertificate -FilePath "$certFullPath"  -CertStoreLocation "$CSLocation" -Password $pfxPassPwsh
               ### assegno un friendly name al certificato appena importato
               $certFriendlyName = "$cn"+ "_" + "$certFileThumbprint"
               $certPathOnSTore = "$CSLocation" + "\" + "$certFileThumbprint"
               (Get-ChildItem -Path $certPathOnSTore).FriendlyName = "$certFriendlyName"
            }
            else
            {
               Write-Output("esiste gia' un certificato con thumbprint $certFileThumbprint sul keystore nel path $CSLocation")
            }
         }
         else
         {
            Write-Output("non riesco a leggere i dati da $certFullPath")
         }
      }
      else
      {
         Write-Output("non trovo un file $certDepot\${cn}\full.pfx")
      }
   }
   else
   {
      Write-Output("non faccio verifiche per ${cn}")
   }
}
