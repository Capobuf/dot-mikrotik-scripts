:do {
    :global requestvalue do={:put $1 ; :return}

    :log info "[firewall-config] Script Avviato"
    # Chiedo se voglio resettare la RB
    :local WantReset [$requestvalue "Vuoi resettare la Routerboard senza Backup e configurazione di default? (y/n)"]

    :if ($WantReset="y" || $WantReset="yes") do={
        /system reset-configuration no-defaults=yes skip-backup=yes
    }

    # Configuro l'utente dot
    :local WantdotUser [$requestvalue "Vuoi configurare l'utente dot come Admin? (y/n)"]
    :do {
        :if ($WantdotUser="y" || $WantdotUser="yes") do={
            :local dotPswd [$requestvalue "Inserisci la Password per l'utente dot:"]
            /user add name=dot group=full comment="bydot.it" password=$dotPswd
        } 
    } on-error={:put "[ERRORE] Nella creazione dell'utente dot"; :log error "Impossibile creare utente dot"}

    :local IdentName [$requestvalue "Hostname della Routerboard:"]
        :do {
            /system identity set name=$IdentName;
            } on-error={ :put "[ERRORE] Non sono riuscito ad impostare l'Hostname"}

    :local WantChangeAdmin [$requestvalue "Vuoi disattivare l'admin e aggiungere super? (y/n)"]

        :if ($WantChangeAdmin="y" || $WantChangeAdmin="yes") do={
            :local superPswd [$requestvalue "Inserisci la Password per l'utente super:"]
            :do {
                /user add name=super group=full comment="Super Admin" password=$superPswd
                /user disable admin
                /user comment admin comment="Disabilitato per motivi di sicurezza - non riabilitare senza prima aver impostato una password"
                } on-error={ :put "[ERRORE] Nella modifica degli utenti"; :log error "Ricontrollare Utenti"}
        }
 
    :put "Configuro il Bridge bridge_lan - RICORDA DI AGGIUNGERE LE PORTE!"

    :do {
        interface bridge add name=bridge_lan comment="LAN Bridge"
        } on-error={ :put "[ERRORE] nella configurazione del Bridge! Controlla e Riesegui lo Script!"; :return}
    
        :global WANInterface [$requestvalue "Inserisci l'inferfaccia che farà da WAN:"]
        :put "Hai scelto come Interfaccia WAN: $WANInterface"

        :do {
        /interface list add name=WAN; /interface list member add interface=$WANInterface list=WAN;
        /interface ethernet set $WANInterface comment=WAN
        } on-error={ :put "[ERRORE] Configurazione Interfaccia WAN"}


    # Configuro la WAN
    :local WantConfigWAN [$requestvalue "Vuoi configurare la WAN ora? (dhcp/ppp/n)"]
    :local cont 0;
    :local loading #;
    
    :if ($WantConfigWAN="dhcp") do={
        /ip dhcp-client add interface=$WANInterface use-peer-dns=yes add-default-route=yes disabled=no;
        :delay 2s;
        :local dhcpstat;
        while (($cont<=15) and (:global dhcpstat [ip dhcp-client get $WANInterface status] != "bound")) do={
            :put "Aspetto un lease..."
            :set dhcpstat [ip dhcp-client get bridge_wan status];
            :put $loading
            :delay 1s
            :set cont ($cont+1);
            :set loading ($loading."#")
        }
        :put "Lo stato del dhcp-client è:"
        /ip dhcp-client print;
    }

    if ($WantConfigWAN="ppp") do={

        :local PPPoeUsername [$requestvalue "Username PPPoE:"]
        :local PPPoePSWD [$requestvalue "Password PPPoE:"]
        :local PPPoeName [$requestvalue "Nome della PPPoE?:"]
        :do {
            /interface pppoe-client add name=$PPPoeName interface=$WANInterface user=$PPPoeUsername password=$PPPoePSWD use-peer-dns=yes add-default-route=yes disabled=no;
            /interface list member add interface=$PPPoeName list=WAN

            :local pppoestat;
            /interface pppoe-client monitor $PPPoeName once do={:set pppoestat $status};

            while (($cont<=15) and (pppoestat != "connected")) do={
                :put "In attesa del Server PPPoE..."
                /interface pppoe-client monitor $PPPoeName once do={:set pppoestat $status};
                :put $loading
                :delay 1s
                :set cont ($cont+1);
                :set loading ($loading."#")
            }
            :put "Lo stato di $PPPoeName è:"
            /interface pppoe-client monitor $PPPoeName once
        } on-error={ :put "[ERRORE] Configurazione PPPoE-Client fallita"; :log error "Configura il PPPoE-Client"}
    
    }

    :do {
    :global LANSubnet [$requestvalue "Inserisci la Subnet della LAN (0.0.0.0/0):"]
    /ip firewall address-list add list=LAN_Subnet address=$LANSubnet
    /ip firewall address-list add address=$LANSubnet list=Allowed_Management

    :local LANGW [$requestvalue "Inserisci il Gateway della LAN (0.0.0.1/0):"]
    /ip address add interface=bridge_lan address=$LANGW comment="LAN Gateway"
    
    :local ErrorDHCPSetup; :set ErrorDHCPSetup "n";
    
    :while ($ErrorDHCPSetup!="y") do={
        :do {
            :put "Configuro il DHCP Server con il Setup [CONFIGURA INTERFACCIA bridge_lan]";
            /ip dhcp-server setup;
            :set ErrorDHCPSetup "y";
            :put "[DEBUG] ErrorDHCPSetup: $ErrorDHCPSetup"
            } on-error={:set ErrorDHCPSetup [$requestvalue "Errore nella configurazione del DHCP Server, vuoi riprovare? (y/n):"]}
    }
    
    :put "Rinomino il DHCP Server in dhcp-server-lan"
    /ip dhcp-server set dhcp1 name=dhcp-server-lan;
    :put "Commento la network specificando che è la Subnet della LAN"
    ip dhcp-server network comment numbers=0 comment="Subnet LAN";
    :put "Abilito Richieste Remote DNS"
    /ip dns set allow-remote-requests=yes

    } on-error={ :put "[ERRORE] Configurazione LAN e/o DHCP Server!"; :log error "Configura la LAN/DHCP-Server Manualmente";}
    
    :put "Disabilito IPv6"
    /ipv6 settings set disable-ipv6=yes
    
    #### Configuro il Firewall
    :put "Configuro il NAT"
    /ip firewall nat add action=masquerade chain=srcnat comment="Masquerade x LAN" src-address-list=LAN_Subnet out-interface-list=WAN;

    :local ShutService [$requestvalue "Spengo tutti i Servizi TRANNE SSH e Winbox? (y/n)"]
    :if ((ShutService=y) || (ShutService=yes)) do={/ip service disable api,ftp,telnet,www,www-ssl,api-ssl}

    :local SipALGOff [$requestvalue "Spengo il SIP ALG? (y/n)"]
    :if ((SipALGOff=y) || (SipALGOff=yes)) do={/ip firewall service-port disable sip}

    #:local ShutService [$requestvalue "Aggiungo voip.dimensione.com come esclusione? (y/n)"]
    #:if (($ShutService=y) || ($ShutService=yes)) do={/ip service disable api,ftp,telnet,www,www-ssl,api-ssl}

    :local InstLightBlack [$requestvalue "Installo la Blacklist Light? (y/n)"];
    :if ((InstLightBlack=y) || (InstLightBlack=yes)) do={
        :do {
            /system script add name="pwlgrzs-blacklist-dl" source={/tool fetch url="https://raw.githubusercontent.com/pwlgrzs/Mikrotik-Blacklist/master/blacklist-light.rsc" mode=https};
            :delay 1s
            /system script add name="pwlgrzs-blacklist-replace" source {/ip firewall address-list remove [find where list="pwlgrzs-blacklist"]; /import file-name=blacklist-light.rsc; /file remove blacklist-light.rsc};
            :delay 1s
            /system scheduler add interval=7d name="dl-mt-blacklist" start-date=Jan/01/2000 start-time=00:05:00 on-event=pwlgrzs-blacklist-dl
            /system scheduler add interval=7d name="ins-mt-blacklist" start-date=Jan/01/2000 start-time=00:10:00 on-event=pwlgrzs-blacklist-replace
            :delay 1s
            /ip firewall filter add chain=input comment="Droppo da Blacklist" action=drop connection-state=new src-address-list=pwlgrzs-blacklist in-interface-list=WAN
        } on-error {:put "[ERRORE] Nell'installazione della Blacklist"; :log error "Installazione Blacklist Light non riuscita"}
    }

    /ip firewall filter add action=passthrough chain=forward comment="########## INPUT CHAIN ##########" disabled=yes
    /ip firewall filter add action=drop chain=input comment="Droppo le INVALID" connection-state=invalid
    /ip firewall filter add action=accept chain=input comment="Consento Enst. e Releated" connection-state=established,related
    
    ### SE METTO NO SCRIVE COMUNQUE DA FIXARE
    :global yesL2TP;
    :set yesL2TP [$requestvalue "Inserisco la Regola in INPUT per L2TP/IPSEC? (y/n)"];
    :if (($yesL2TP="y") || ($yesL2TP="yes")) do={
    /ip firewall filter add action=passthrough chain=forward comment="########## L2TP/IPSEC ##########" disabled=yes
    /ip firewall filter add action=accept chain=input comment="Consento L2TP solo se IPSec" dst-port=1701 ipsec-policy=in,ipsec protocol=tcp
    /ip firewall filter add action=accept chain=input comment="Consento il resto di L2TP/IPSec" dst-port=161,500,4500 protocol=udp
    }

    :local yesOpenVPN [$requestvalue "Inserisco la Regola in INPUT per OPENVPN? (y/n)"]
    :if (($yesOpenVPN="y") || ($yesOpenVPN="yes")) do={
        /ip firewall filter add action=passthrough chain=forward comment="########## OpenVPN ##########" disabled=yes
        /ip firewall filter add action=accept chain=input comment="Consento OpenVPN IN" dst-port=2005 protocol=udp log-prefix=OVPN_IN
    }

    /ip firewall filter add action=drop chain=input comment="DROP ALL INPUT WAN" in-interface-list=WAN log-prefix=DROP_ALL_IN
    /ip firewall filter add action=drop chain=input comment="[BCK RULE] Droppo i non Allowed alle porte di Management" dst-port=21,22,23,80,443,8291,8728,8729 in-interface-list=WAN protocol=tcp src-address-list=!Allowed_Management log-prefix=NO_ALLWD
    /ip firewall filter add action=passthrough chain=input comment="########## FORWARD CHAIN ##########" disabled=yes
    /ip firewall filter add action=drop chain=forward comment="Droppo le INVALID" connection-state=invalid
    /ip firewall filter add action=drop chain=forward comment="Droppo tutto il non DSTNATed dalla WAN" connection-nat-state=!dstnat connection-state=new in-interface-list=WAN log-prefix=NON_DSTNAT
    /ip firewall filter add action=fasttrack-connection chain=forward comment="Fasttrack per Enst. e Releated" connection-state=established,related hw-offload=yes
    /ip firewall filter add action=accept chain=forward comment="Accetto Enst. e Releated" connection-state=established,related
    /ip firewall filter add action=accept chain=forward comment="Consento l'uscita della LAN sulla WAN" out-interface-list=WAN src-address-list=LAN_Subnet
    /ip firewall filter add action=drop chain=forward comment="Droppo tutto il NON LAN sulla WAN" in-interface=bridge_lan out-interface-list=WAN src-address-list=!LAN_Subnet log-prefix=NON_WAN
    /ip firewall filter add action=drop chain=forward comment="DROP ALL FORWARD" log=yes log-prefix=FWD_DROP

    :put "Configuro il Client NTP"

    /system clock set time-zone-name=Europe/Rome
    /system ntp client servers add address=193.204.114.232 comment="INRIM 1 - IPv4"
    /system ntp client servers add address=193.204.114.233 comment="INRIM 2 - IPv4"
    /system ntp client servers add address=time.inrim.it comment="INRIM NTP - FQND"
    /system ntp client servers add address=time.google.com comment="Google NTP - FQND"
    /system ntp client/set enabled=yes
    :delay 10s
    :put "Stato del Client NTP"
    /system ntp client/print without-paging;

    /beep

}