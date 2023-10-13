#!/bin/bash

# Función de ayuda
help() {
  echo "Uso: $0 [-o ORIGEN] [-d DESTINO] [-u USUARIO] [-p PASSPHRASE]"
  echo "  -o ORIGEN    Dirección IP o nombre de host del servidor de origen (Ubuntu)"
  echo "  -d DESTINO   Dirección IP o nombre de host del servidor de destino (Fedora)"
  echo "  -u USUARIO   Nombre de usuario SSH en el servidor de origen"
  echo "  -p PASSPHRASE Frase de paso para cifrar el archivo de respaldo"
  exit 1
}

# Valores predeterminados
ORIGEN=""
DESTINO=""
USUARIO=""
PASSPHRASE=""

# Procesar argumentos
while getopts "o:d:u:p:h" opt; do
  case "$opt" in
    o) ORIGEN=$OPTARG ;;
    d) DESTINO=$OPTARG ;;
    u) USUARIO=$OPTARG ;;
    p) PASSPHRASE=$OPTARG ;;
    h) help ;;
    \?) echo "Opción no válida: -$OPTARG" >&2; help ;;
  esac
done

# Validar argumentos
if [ -z "$ORIGEN" ] || [ -z "$DESTINO" ] || [ -z "$USUARIO" ] || [ -z "$PASSPHRASE" ]; then
  echo "Faltan argumentos obligatorios."
  help
fi

# Comprobar si se proporcionó una contraseña o utilizar la autenticación con clave SSH
OPCIONES_SCP="-o PasswordAuthentication=no"

# Rutas de directorio
ORIGEN_DIR="/home/$USUARIO"
DESTINO_DIR="/home/$USUARIO/DPAdmin16-2023#66"

# Calcular el hash SHA-256 del contenido antes del cifrado en el origen
SHA256_PRE_ENCRYPT=$(tar cz "$ORIGEN_DIR" | sha256sum | awk '{print $1}')

# Comprimir y cifrar la copia de seguridad en el servidor origen
tar czf - "$ORIGEN_DIR" | gpg --batch --symmetric --passphrase "$PASSPHRASE" | ssh $OPCIONES_SCP $USUARIO@$ORIGEN "cat > /tmp/backup.tar.gz.gpg"

# Copiar la copia de seguridad al servidor destino
scp $OPCIONES_SCP $USUARIO@$ORIGEN:/tmp/backup.tar.gz.gpg "$DESTINO:$DESTINO_DIR"

# Descomprimir y descifrar la copia de seguridad en el servidor destino
ssh $DESTINO "cd $DESTINO_DIR && gpg --batch --decrypt --passphrase $PASSPHRASE -o backup.tar.gz /tmp/backup.tar.gz.gpg && tar xzf backup.tar.gz"

# Calcular el hash SHA-256 del contenido después del descifrado en el destino
SHA256_POST_DECRYPT=$(tar cz "$DESTINO_DIR" | sha256sum | awk '{print $1}')

# Limpiar archivos temporales en el servidor origen y destino
ssh $USUARIO@$ORIGEN "rm /tmp/backup.tar.gz.gpg"
ssh $DESTINO "rm $DESTINO_DIR/backup.tar.gz"

# Verificar los hash SHA-256 antes y después de la transferencia
echo "Hash SHA-256 antes del cifrado: $SHA256_PRE_ENCRYPT"
echo "Hash SHA-256 después del descifrado: $SHA256_POST_DECRYPT"

echo "Copia de seguridad completa."
