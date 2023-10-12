:local CN [/system identity get name]
:local USERNAME "username"
:local PASSWORD "password"

# Genero gli Utenti e i loro Certificati
# Per evitare errori nell'esportazione, inserisci una password +8 char
/ppp secret
add name=$USERNAME password=$PASSWORD profile=OVPN-Profile service=ovpn
:delay 2s

## Genero il Certificato per il Client
/certificate
add name="$USERNAME@client-template" copy-from="client-template" common-name="client_$USERNAME@$CN"
sign "$USERNAME@client-template" ca="$CN" name="$USERNAME@$CN"
:delay 2s

## Esporto CA, Certificato Client e Key
/certificate
export-certificate "$CN" export-passphrase=""
export-certificate "$USERNAME@$CN" export-passphrase="$PASSWORD"
/