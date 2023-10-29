    ## Funzione per richiedere l'input e scrivere la variabile
:global requestvalue do={:put $1 ; :return}

:global VLANName;
:global VLANID;
:global VLANSubnet;
:global VLANFullName;
:global VLANShortName;
:global VLANSubnetName;
:global baseIP;
:global gatewayIP;
:global GwSub;
:global StartEndRange;

    ## Ciclo per fare spazio 
:global makeSpace do={ :global count 0; :global spaceCount 50; :while ($count < $spaceCount) do={:put ""; :set count ($count + 1);}}
                                           

:do {
    :log warning "Script di Configurazione delle VLAN Avviato"; :put "Script di Configurazione delle VLAN Avviato"

    :if ([:len [ /interface bridge find name=bridge_vlan ]] = 0) do={
        :put "L'interface list bridge_vlan non esiste. Creazione in corso..."
        /interface bridge add \
        name=bridge_vlan \
        comment="Bridge x VLAN Filtering";
    } else={
        :put "Il bridge_vlan esiste, proseguo."
    }

    $makeSpace

    :global anotherVLAN true;
    :global InfoOk true;



    :while ($anotherVLAN=true) do={

        :while ($InfoOk=true) do={
            $makeSpace
            :set VLANName [$requestvalue "Inserisci il nome della VLAN (es. Ufficio):"]
            $makeSpace
            :set VLANID [$requestvalue "Inserisci la VLAN ID (0-4094):"]
            $makeSpace
            :set VLANSubnet [$requestvalue "Inserisci la Subnet della VLAN, la subnet deve essere /24 (0.0.0.0/24):"]
            $makeSpace

                ## Creo i vari Nomi
            :global VLANFullName ($VLANID . "-" . "VLAN" . "-" . $VLANName)
            :global VLANShortName ($VLANID . "-" . $VLANName)
            :global VLANSubnetName ($VLANShortName . "-Subnet")

                ## Rimuovo il /24 e calcolo il GW e il range
            :set baseIP [:pick $VLANSubnet 0 ([:find $VLANSubnet "/"])]

            :global lastOctet [:pick $baseIP ([:len $baseIP] - 1)]
            :global gatewayLastOctet [:tostr ([:tonum $lastOctet] + 1)]

                ## es. 172.16.0.1
            :set gatewayIP ([:pick $baseIP 0 ([:len $baseIP] - 1)] . $gatewayLastOctet)

            :global startRangeIP ([:pick $baseIP 0 ([:len $baseIP] - 1)] . "2")
            :global endRangeIP ([:pick $baseIP 0 ([:len $baseIP] - 1)] . "254")
            :set StartEndRange "$startRangeIP-$endRangeIP";

                ## es. 172.16.0.1/24
            :set GwSub (:pick $gatewayIP  . "/24")


            :put "Nome VLAN: $VLANName";
            :put "";
            :put "VLAN ID: $VLANID";
            :put "";          
            :put "Nome Completo VLAN: $VLANFullName";
            :put "";
            :put "Subnet VLAN: $VLANSubnet";
            :put "";
            :put "Gateway: $gatewayIP";
            :put "";
            :put "Range IP: $startRangeIP-$endRangeIP";
            :put "";
            :global AreUSure [$requestvalue "Confermi (y/n)?"]
            :if ($AreUSure="y" || $AreUSure="yes") do={:set InfoOk false}
        }

        :put "Subnet VLAN: $VLANSubnet";
        :global wantAllowManagement [$requestvalue "Vuoi Consentire l'accesso alla Management da questa VLAN? (y/n)"]

        :if ($wantAllowManagement="y" || $wantAllowManagement="yes") do={
                :put "Valore di VLANSubnet: $VLANSubnet"
                /ip firewall address-list add \
                list=Allowed_Management \
                address=$VLANSubnet;
                :put ($VLANFullName . " aggiunta ad Allowed Management")
        }

        
        ## Aggiungo la VLAN al Bridge
        /interface vlan
        add interface=bridge_vlan \
        name=$VLANFullName \
        vlan-id=$VLANID;

        ## Creo la VLAN all'interno del Bridge
        /interface bridge vlan
        add bridge=bridge_vlan \
        comment="$VLANFullName" \
        tagged=bridge_vlan \
        vlan-ids=$VLANID;

        ## Creo l'Address List
        /ip firewall address-list add \
        list=$VLANSubnetName \
        address=$VLANSubnet;

        :if ([:len [ /interface list find name=WAN ]] = 0) do={
            :put "La Interface list WAN non esiste. Creazione in corso..."
            /interface list add name=WAN
        } else={
            :put "Interface List WAN esiste, proseguo."
        }

        /ip firewall nat add \
        action=masquerade \
        chain=srcnat \
        comment="Masquerade x $VLANFullName" \
        src-address-list=$VLANSubnetName \
        out-interface-list=WAN;
        :log info "Masquerade x $VLANFullName Configurato";

        /ip firewall filter add \
        action=accept \
        chain=forward \
        comment="Consento l'uscita di $VLANFullName sulla WAN" \
        out-interface-list=WAN \
        src-address-list=$VLANSubnetName;

        :global wantDHCPonVLAN [$requestvalue "Vuoi creare il DHCP Server? (y/n)"]

        :if ($wantDHCPonVLAN="y" || $wantDHCPonVLAN="yes") do={
            


            /ip address add \
            address=$GwSub \
            comment="Gateway x $VLANFullName" \
            interface=$VLANFullName;

            :global vlanPoolName [($VLANFullName . "-dhcp-pool")]

            /ip pool add \
            name=$vlanPoolName \
            ranges=$StartEndRange;

            :global SelLeaseTime [$requestvalue "Tempo di lease (es. gg:hh:mm / 00:00:00)?"];

            /ip dhcp-server add \
            address-pool=$vlanPoolName \
            interface=$VLANFullName \
            name=[$VLANShortName . "-server-lan"] \
            comment="DHCP Server x $VLANShortName" \
            lease-time="$SelLeaseTime";

            :global domainName [$requestvalue "Inserisci Nome del Dominio (example.lan)"];

            /ip dhcp-server network add \
            address="$VLANSubnet" \
            comment="Network x LAN" \
            domain="$domainName" \
            dns-server="$gatewayIP" \
            gateway="$gatewayIP";

        }

        :global wantCreateAnotherVLAN [$requestvalue "Vuoi creare una nuova VLAN? (y/n)"]

        :if ($wantCreateAnotherVLAN="y" || $wantCreateAnotherVLAN="yes") do={
            :set anotherVLAN true;
        } else {:set anotherVLAN false;}

    }

    ## Pulisco gli enviroments

    /system script environment remove [find];

    /beep;


}