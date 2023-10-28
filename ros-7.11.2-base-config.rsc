:global CN "TEST-01"
:global superPassword "superpassword"
:global dotPassword "dotpassword"
:global PrimaryWAN "ether1"
:global SecondaryWAN "ether2"
:global typeWAN "pppoe"
:global haveVLAN "yes"

:do {
    /system identity set name=$CN;
} on-error={:log error "Non sono riuscito ad impostare l'Hostname"}

:do {
        ## Aggiungo l'utente Super
        /user add \
        name=super \
        group=full \
        comment="Super Admin" \
        password=$superPswd;

        ## Disabilito l'admin di default
        /user disable admin;
        ## Commento l'Admin
        /user comment admin \
        comment="Disabilitato per motivi di sicurezza - non riabilitare senza prima aver impostato una password";
        ## Aggiungo l'utente dot
        /user add \
        name=dot \
        group=full \
        comment="bydot.it // Tecnico" \
        password=$dotPassword;

} on-error={:log error "Errore nella modifica degli Utenti"}

## Configuro la WAN
:do {
/interface list add \
name=WAN; 

/interface list member add \
interface=$WANInterface \
list=WAN;

/interface ethernet set $WANInterface \
comment=WAN;

} on-error={:log error "Errore nella modifica degli Utenti"; :return}

## Configuro il Bridge
:do {
    interface bridge add \
    name=bridge_lan \
    comment="LAN Bridge";
} on-error={:log error "Errore nella creazione del Bridge LAN"; :return}

