$version="1.0.0"

Write-Output("Starting certDownloader vers $version")

#un file che contiene una riga per ogni certificaot (CN) da scaricare
$certList = 'c:\EngScripts\certDownloader\certDownloader.ps1.list'

#la directory locale i ncui conservare i files
$certDepot = 'c:\EngScripts\certDownloader\localDepot'

#il percorso di pscp.exe
$pscp = 'c:\EngScripts\bin\pscp.exe'

#il percorso della chiave privata certdepot in formato putty
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
}
