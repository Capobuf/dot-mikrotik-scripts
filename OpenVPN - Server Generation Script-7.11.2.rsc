# OpenVPN Server Setup Generation Script

:global LOC "Campobasso"
:global ORG "Rock Inc"
:global OU "IT"
:global PORTA "2005"
:global SUBNET "10.100.55.0/24"
:global RANGE "10.100.55.10-10.100.55.25"
:global OVPNGW "10.100.55.1"
:global OVPNDNS "10.100.55.1"
:global OnlyOne "no"
:global CN "CBPAGLIA-01"
:global USERNAME "franco"
# La Password deve essere di almeno 8 caratteri!
:global PASSWORD "roccorocco"

## Genero la CA
/certificate add \
name=ca-template\
country="IT" \
state="Italy" \
locality="$LOC" \
organization="$ORG" \
unit="$OU" \
common-name="$CN" \
days-valid=3650 \
key-usage=crl-sign,key-cert-sign;

/certificate sign ca-template \
ca-crl-host=127.0.0.1 \
name=$CN;

:delay 100ms;

## Genero il Certificato Server
/certificate add \
name=server-template \
country="IT" \
state="Italy" \
locality="$LOC" \
organization="$ORG" \
unit="$OU" \
common-name="server@$CN" \
days-valid=3650 \
key-usage=digital-signature,key-encipherment,tls-server;

/certificate sign \
server-template \
ca="$CN" \
name="server@$CN";

:delay 100ms;

## Genero il Template per il Client
/certificate add \
name=client-template \
country="IT" \
state="Italy" \
locality="$LOC" \
organization="$ORG" \
unit="$OU" \
common-name="client" \
days-valid=3650 \
key-usage=tls-client;

:delay 100ms;

# Genero gli Utenti e i loro Certificati
/ppp secret add \
name="$USERNAME" \
password="$PASSWORD" \
profile=OVPN-Profile \
service=ovpn;

:delay 100ms;

## Genero il Certificato per il Client
/certificate add \
name="client-template-to-issue" \
copy-from="client-template" \
common-name="client-$USERNAME@$CN";

/certificate sign client-template-to-issue \
ca="$CN" \

name="$USERNAME@$CN";

:delay 1s;

## Esporto CA, Certificato Client e Key
/certificate export-certificate "$CN" export-passphrase="" file-name="CA";

/certificate \
export-certificate "$USERNAME@$CN" \
export-passphrase="$PASSWORD" \
file-name="$USERNAME@$CN";

## Creo il Range di IP per il Pool OVPN
/ip pool add \
name=OVPN-Pool \
ranges=$RANGE;

## Creo l'Address List
/ip firewall address-list add \
address="$SUBNET" \
list=OpenVPN_Subnet;

## Creo le regole di Firewall
/ip firewall filter add \
action=accept \
chain=input \
comment="Consento OpenVPN UDP IN da WAN" \
in-interface-list=WAN;

/ip firewall filter add \
action=accept \
chain=forward \
comment="Consento Forward OpenVPN";

## Configuro il NAT
/ip firewall nat add \
action=masquerade \
chain=srcnat \
comment="Masquerade x OpenVPN" \
src-address-list=OpenVPN_Subnet;

## Creo il Profilo PPP
/ppp profile add \
dns-server=$OVPNDNS \
local-address=$OVPNGW \
name=OVPN-Profile \
remote-address=OVPN-Pool \
use-encryption=yes \
only-one=$OnlyOne;

## Configuro il Server OpenVPN
/interface ovpn-server server set \
auth=sha1,sha256 \
certificate="server@$CN"\
cipher=aes128-cbc,aes192-gcm,aes256-gcm,aes256-cbc \
default-profile=OVPN-Profile \
enabled=yes \
keepalive-timeout=7200 \
mac-address=00:00:00:00:00:00 \
max-mtu=1500 \
port="$PORTA" \
protocol=udp \
require-client-certificate=yes;

## Esporto OVPN File

/interface ovpn-server server \
export-client-configuration ca-certificate="CA.crt" \
client-certificate="$USERNAME@$CN.crt" \
client-cert-key="$USERNAME@$CN.key" \
server-address="PUBLIC_IP";

## Rimuovo gli environment

/system script environment remove [find];
beep;
