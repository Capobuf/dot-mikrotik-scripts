# OVPN Server / One Cert 4 All
:global LOC "Localita"
:global ORG "Azienda"
:global OU "IT"
:global PORTA "2005"
:global SUBNET "10.100.55.0/24"
:global RANGE "10.100.55.10-10.100.55.100"
:global OVPNGW "10.100.55.1"
:global OVPNDNS "10.100.55.1"
:global OnlyOne "no"
:global CN "RouterName"
:global PASSWORD "Password-Private-Key"

## Genero la CA
/certificate add \
name=ca-template \
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

:delay 2s;

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

:delay 2s;

## Genero un Certificato Unico per il Client
/certificate add \
name=client-template \
country="IT" \
state="Italy" \
locality="$LOC" \
organization="$ORG" \
unit="$OU" \
common-name="client@$CN" \
days-valid=3650 \
key-usage=tls-client;

/certificate sign client-template \
ca="$CN" \
name="client@$CN";

:delay 2s;

## Esporto CA, Certificato Client e Key
/certificate export-certificate "$CN" export-passphrase="" file-name="CA";

/certificate \
export-certificate "client@$CN" \
export-passphrase="$PASSWORD" \
file-name="client@$CN";

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
/ppp profile add name="OVPN-Profile" \
dns-server=$OVPNDNS \
local-address=$OVPNGW \
remote-address=OVPN-Pool \
use-encryption=yes \
only-one=$OnlyOne;

# Genero gli Utenti (riutilizzano lo stesso certificato client)
/ppp secret add \
name="utente1" \
password="$PASSWORD" \
profile=OVPN-Profile \
service=ovpn;

/ppp secret add \
name="utente2" \
password="$PASSWORD" \
profile=OVPN-Profile \
service=ovpn;

## Configuro il Server OpenVPN
/interface ovpn-server server set \
auth=sha1,sha256,sha512 \
certificate="server@$CN" \
cipher=aes128-cbc,aes192-gcm,aes256-gcm,aes256-cbc \
default-profile=OVPN-Profile \
keepalive-timeout=7200 \
max-mtu=1500 \
port="$PORTA" \
protocol=udp \
disabled=no \
name=OVPN_Server \
enable-tun-ipv6=no \
numbers=0 \
mode=ip \
require-client-certificate=yes;

## Esporto OVPN File
/interface ovpn-server server \
export-client-configuration ca-certificate="CA.crt" \
client-certificate="client@$CN.crt" \
client-cert-key="client@$CN.key" \
server-address="PUBLIC_IP";

## Rimuovo gli environment
/system script environment remove [find];
beep;