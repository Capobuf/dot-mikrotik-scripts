# Inserisci lo Stesso CN inserito quando hai fatto il Server!
:global CN "CN-NAME"
:global USERNAME "username"
:global PASSWORD "password"

# Genero gli Utenti e i loro Certificati
# Per evitare errori nell'esportazione, inserisci una password +8 char
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

:delay 100ms;

## Esporto i Certificati e la Chiave per il Client
/certificate export-certificate "$USERNAME@$CN" \
export-passphrase="$PASSWORD" \
file-name="$USERNAME@$CN";

:delay 200ms;

## Esporto OVPN File

/interface ovpn-server server \
export-client-configuration ca-certificate="CA.crt" \
client-certificate="$USERNAME@$CN.crt" \
client-cert-key="$USERNAME@$CN.key" \
server-address="PUBLIC_IP";

# Rimuovo le Variabili Globali

/system script environment remove USERNAME,PASSWORD,CN;
beep;
