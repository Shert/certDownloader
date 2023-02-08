$version="1.0.1a"

Write-Output("Starting certDownloader vers $version")

### password base64 encoded
$pfxPassEnc='xxx_inserire_qui_la_password_codificata_in_base64'
$pfxPassClear = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($pfxPassEnc))
$pfxPassPwsh = ConvertTo-SecureString -String "$pfxPassClear" -Force -AsPlainText

### path del CertStoreLocation sul server
$CSLocation = 'Cert:\LocalMachine\My'

### un file che contiene una riga per ogni certificato (CN) da scaricare
$certList = 'c:\EngScripts\certDownloader\certDownloader.ps1.list'

### la directory locale in cui conservare i files
$certDepot = 'c:\EngScripts\certDownloader\localDepot'

### il percorso di pscp.exe
$pscp = 'c:\EngScripts\bin\pscp.exe'

### il percorso della chiave privata certdepot in formato putty
$sftpCert = 'c:\EngScripts\certDownloader\certdepot.ppk'

$sftpUser = 'xxx_inserire_qui_la_userxxx'
$sftpHost = 'xxx_inserrire_qui_ip_o_fqdn_da_cui_copiare_i_certificati'

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
$certificates = Get-Content -Path $certList

foreach ( $cn in  $certificates)
{
   Write-Output("provo a scaricare : $cn")
   ##c:\EngScripts\bin\pscp.exe -r -l ${sftpUser} -i ${sftpCert} -C ${sftpHost}:/${cn} ${certDepot}"
   & "$pscp" -r -l ${sftpUser} -i ${sftpCert} -C ${sftpHost}:/${cn} ${certDepot}
   
   $certFullPath = "$certDepot" + "\" + "$cn" + "\full.pfx" 
   ### verifico se esiste un file full.pfx nel path relativo al certificato che sto lavorando
   if  (Test-Path -Path  "$certFullPath" -PathType leaf)
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
