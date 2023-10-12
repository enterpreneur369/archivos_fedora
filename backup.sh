#!/bin/bash

# Función de ayuda
help() {
  echo "Uso: $0 [-o ORIGEN] [-d DESTINO] [-u USUARIO] [-p CONTRASEÑA]"
  echo "  -o ORIGEN    Dirección IP o nombre de host del servidor de origen (Ubuntu)"
  echo "  -d DESTINO   Dirección IP o nombre de host del servidor de destino (Fedora)"
  echo "  -u USUARIO   Nombre de usuario SSH en el servidor de origen"
  echo "  -p CONTRASEÑA Contraseña del usuario SSH (opcional, se recomienda el uso de claves SSH)"
  exit 1
}

# Valores predeterminados
ORIGEN=""
DESTINO=""
USUARIO=""
CONTRASENA=""

# Procesar argumentos
while getopts "o:d:u:p:h" opt; do
  case "$opt" in
    o) ORIGEN=$OPTARG ;;
    d) DESTINO=$OPTARG ;;
    u) USUARIO=$OPTARG ;;
    p) CONTRASENA=$OPTARG ;;
    h) help ;;
    \?) echo "Opción no válida: -$OPTARG" >&2; help ;;
  esac
done

# Validar argumentos
if [ -z "$ORIGEN" ] || [ -z "$DESTINO" ] || [ -z "$USUARIO" ]; then
  echo "Faltan argumentos obligatorios."
  help
fi

# Comprobar si se proporcionó una contraseña o utilizar la autenticación con clave SSH
if [ -n "$CONTRASENA" ]; then
  OPCIONES_SCP="-o PasswordAuthentication=yes"
else
  OPCIONES_SCP="-o PasswordAuthentication=no"
fi

# Rutas de directorio
ORIGEN_DIR="/home/$USUARIO/DPAdmin16-2023#66"
DESTINO_DIR="/backup_origen2023"

# Comprimir y cifrar la copia de seguridad en el servidor origen
tar czf - "$ORIGEN_DIR" | gpg -c --passphrase "$CONTRASENA" | ssh $OPCIONES_SCP $USUARIO@$ORIGEN "cat > /tmp/backup.tar.gz.gpg"

# Copiar la copia de seguridad al servidor destino
scp $OPCIONES_SCP $USUARIO@$ORIGEN:/tmp/backup.tar.gz.gpg "$DESTINO:$DESTINO_DIR"

# Descomprimir y descifrar la copia de seguridad en el servidor destino
ssh $DESTINO "cd $DESTINO_DIR && gpg -d --passphrase $CONTRASENA -o backup.tar.gz /tmp/backup.tar.gz.gpg && tar xzf backup.tar.gz"

# Limpiar archivos temporales en el servidor origen y destino
ssh $USUARIO@$ORIGEN "rm /tmp/backup.tar.gz.gpg"
ssh $DESTINO "rm $DESTINO_DIR/backup.tar.gz"

echo "Copia de seguridad completa."
