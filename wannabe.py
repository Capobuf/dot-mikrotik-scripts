import paramiko

router_ip = "indirizzo_ip_del_router"
username = "nome_utente"
password = "password"

# Crea una connessione SSH
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(router_ip, username=username, password=password)

# Comando da eseguire sul RouterOS
command = "/system/resource/print"

# Esegui il comando e ottieni l'output
stdin, stdout, stderr = ssh.exec_command(command)
output = stdout.read().decode()

# Chiudi la connessione SSH
ssh.close()

print("Output del comando:", output)

