#Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);

# Get the security principal for the administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

# Check to see if we are currently running as an administrator
function GoAdmin { Start-Process powershell –Verb RunAs }
#----------------------------------------------------------[Declarations]----------------------------------------------------------
#Install-Module -Name VPNCredentialsHelper 
Pause
$Name = Read-Host -Prompt 'Inserisci il nome della Connessione'
$ServerAddr = Read-Host -Prompt 'Inserisci IP Pubblico o dominio'
$L2TPPSK = Read-Host -Prompt 'Inserisci la Pre-Shared Key IPSEC'
$username = Read-Host -Prompt 'Inserisci Nome Utente'
$plainpassword = Read-Host -Prompt 'Inserisci Password'
$Routetorem = Read-Host -Prompt 'Inserisci la rotta remota nel formato CIDR 192.168.1.0/24'
$NAT = Read-Host -Prompt '0 = NO NAT | 1 = SERVER dietro NAT | 2 = SERVER e CLIENT dietro NAT '

#-----------------------------------------------------------[Execution]------------------------------------------------------------
Import-Module VpnClient
Add-VpnConnection -RememberCredential -Name $Name -ServerAddress $ServerAddr -AuthenticationMethod MSChapv2 -TunnelType L2tp -EncryptionLevel Required -L2tpPsk $L2TPPSK -Force
Set-VpnConnectionUsernamePassword -connectionname $Name -username $username -password $plainpassword -domain ''
Add-VpnConnectionRoute -ConnectionName $Name -DestinationPrefix $Routetorem -PassThru
Set-VPNconnection -name $Name -SplitTunneling $true
Set-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\PolicyAgent" -Name "AssumeUDPEncapsulationContextOnSendRule" -Type DWORD -Value $NAT –Force;
Write-Host "La Connessione VPN è stata Creata  :)"
Write-Host "VPN:" $Name
Write-Host "Server:" $ServerAddr
Write-Host "Pre-Shared key:" $L2TPPSK "usata."
Write-Host "Altre info in basso...."
Get-VpnConnection | fl
Pause

