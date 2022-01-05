# OpenVPN Server Setup Generation Script


# Inizio a creare la CA e i Certificati per Server e Client

:global CN [/system identity get name]
:global PAESE "IT"
:global STATO "Italy"
:global LOC "Città"
:global ORG "DOT"
:global OU ""
:global KEYSIZE "2048"
:global PORTA "2005"
:global RANGE "192.168.68.10-192.168.68.25"
:global OVPNGW "192.168.68.1"
:global OVPNDNS "192.168.68.1"
:global PROTO "tcp"
:global CN [/system identity get name]
:global USERNAME "username vpn profile"
:global PASSWORD "password vpn profile"

## Aspetto per evitare di bloccare le rb più scarse
:global waitSec do={:return ($KEYSIZE * 10 / 1024)}

## Genero la CA
/certificate
add name=ca-template country="$PAESE" state="$STATO" locality="$LOC" \
  organization="$ORG" unit="$OU" common-name="$CN" key-size="$KEYSIZE" \
  days-valid=3650 key-usage=crl-sign,key-cert-sign
sign ca-template ca-crl-host=127.0.0.1 name="$CN"
:delay [$waitSec]

## Genero il Certificato Server
/certificate
add name=server-template country="$PAESE" state="$STATO" locality="$LOC" \
  organization="$ORG" unit="$OU" common-name="server@$CN" key-size="$KEYSIZE" \
  days-valid=3650 key-usage=digital-signature,key-encipherment,tls-server
sign server-template ca="$CN" name="server@$CN"
:delay [$waitSec]

## Genero il Template per il Client
/certificate
add name=client-template country="$PAESE" state="$STATO" locality="$LOC" \
  organization="$ORG" unit="$OU" common-name="client" \
  key-size="$KEYSIZE" days-valid=3650 key-usage=tls-client

## Creo il Range di IP per il Pool OVPN
/ip pool add name=OVPN-Pool ranges=$RANGE

## Creo il Profilo PPP
/ppp profile
add dns-server=$OVPNDNS local-address=$OVPNGW name=OVPN-Profile \
  remote-address=OVPN-Pool use-encryption=yes only-one=yes

## Configuro il Server OpenVPN
/interface ovpn-server server
set auth=sha1 certificate="server@$CN" cipher=aes128,aes192,aes256 \
  default-profile=OVPN-Profile enabled=yes keepalive-timeout=60 \
  mac-address=00:00:00:00:00:00 max-mtu=1450 port="$PORTA" \
  require-client-certificate=yes

## add a firewall rule
/ip firewall filter
add chain=input dst-port="$PORTA" protocol=$PROTO comment="OpenVPN $PROTO IN"


# Genero gli Utenti e i loro Certificati
# Per evitare errori nell'esportazione, inserisci una password +8 char
/ppp secret
add name=$USERNAME password=$PASSWORD profile=OVPN-Profile service=ovpn

## Genero il Certificato per il Client
/certificate
add name=client-template-to-issue copy-from="client-template" \
  common-name="$USERNAME@$CN"
sign client-template-to-issue ca="$CN" name="$USERNAME@$CN"
:delay 20

## Esporto CA, Certificato Client e Key
/certificate
export-certificate "$CN" export-passphrase=""
export-certificate "$USERNAME@$CN" export-passphrase="$PASSWORD"
/
