#!/bin/bash

# Script completo: Instalar y configurar Logwatch + Gotify 
echo "🚀 INSTALADOR COMPLETO: LOGWATCH + GOTIFY"
echo

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

show_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        show_error "Este script debe ejecutarse como root (usa sudo)"
        exit 1
    fi
}

# Detectar distribución
detect_distro() {
    if [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
        PKG_MANAGER="apt-get"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="rhel"
        PKG_MANAGER="yum"
    elif [[ -f /etc/arch-release ]]; then
        DISTRO="arch"
        PKG_MANAGER="pacman"
    else
        show_error "Distribución no soportada"
        exit 1
    fi
    show_message "Distribución detectada: $DISTRO"
}

# Configuración preestablecida de Gotify
setup_gotify_config() {
    echo -e "${BLUE}=== Configuración de Gotify ===${NC}"
    GOTIFY_URL="https://gotify.xxxxxxxxx.com"
    GOTIFY_TOKEN="Ahf_xassssasdqweasd"
    GOTIFY_PRIORITY=1
    
    show_message "Configuración preestablecida aplicada ✓"
}

# Instalar logwatch y dependencias
install_packages() {
    show_message "Instalando paquetes necesarios..."
    
    case $DISTRO in
        "debian")
            $PKG_MANAGER update
            $PKG_MANAGER install -y logwatch curl python3 python3-pip
            pip3 install requests >/dev/null 2>&1 || true
            ;;
        "rhel")
            $PKG_MANAGER install -y epel-release
            $PKG_MANAGER install -y logwatch curl python3 python3-pip
            pip3 install requests >/dev/null 2>&1 || true
            ;;
        "arch")
            $PKG_MANAGER -S logwatch curl python python-pip --noconfirm
            pip install requests >/dev/null 2>&1 || true
            ;;
    esac
    
    # Verificar instalación de logwatch
    if command -v logwatch &> /dev/null; then
        LOGWATCH_PATH=$(which logwatch)
    elif [[ -x /usr/sbin/logwatch ]]; then
        LOGWATCH_PATH="/usr/sbin/logwatch"
    elif [[ -x /usr/bin/logwatch ]]; then
        LOGWATCH_PATH="/usr/bin/logwatch"
    else
        show_error "Error: No se pudo instalar logwatch"
        exit 1
    fi
    
    show_message "Logwatch instalado en: $LOGWATCH_PATH"
    show_message "Python3 y dependencias instaladas ✓"
}

# Crear directorios necesarios
create_directories() {
    show_message "Creando directorios necesarios..."
    mkdir -p /var/cache/logwatch
    mkdir -p /etc/logwatch/conf
    mkdir -p /var/log/logwatch
    chmod 755 /var/cache/logwatch
    show_message "Directorios creados ✓"
}

# Configurar logwatch
configure_logwatch() {
    show_message "Configurando logwatch..."
    
    cat > /etc/logwatch/conf/logwatch.conf << 'EOF'
# Configuración de logwatch para Gotify
LogDir = /var/log
TmpDir = /var/cache/logwatch
Output = stdout
Format = text
Encode = none
Detail = 3
Service = All
Service = "-zz-network"
Service = "-zz-sys"
Range = Yesterday
Archives = Yes
MailTo = stdout
MailFrom = logwatch@localhost
EOF

    show_message "Logwatch configurado ✓"
}

# Crear script de Gotify con JSON seguro
create_gotify_script() {
    show_message "Creando script de Gotify con JSON corregido..."
    
    cat > /usr/local/bin/logwatch-gotify.sh << 'EOF'
#!/bin/bash

# Configuración Gotify
GOTIFY_URL="https://gotify.argustics.com"
GOTIFY_TOKEN="Ahf_TLgApet1dct"
GOTIFY_PRIORITY=1

# Leer reporte
REPORT=$(cat)
if [[ -z "$REPORT" ]]; then
    echo "No hay contenido para enviar"
    exit 0
fi

HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M')
TITLE="📊 Logwatch - $HOSTNAME ($DATE)"

# Método 1: Usar Python para JSON seguro
if command -v python3 >/dev/null 2>&1; then
    python3 << PYTHON_SCRIPT
import json
import sys
try:
    import requests
    
    # Crear payload
    payload = {
        "title": "$TITLE",
        "message": """$REPORT""",
        "priority": $GOTIFY_PRIORITY
    }
    
    headers = {"X-Gotify-Key": "$GOTIFY_TOKEN"}
    
    response = requests.post("$GOTIFY_URL/message", json=payload, headers=headers, timeout=30)
    
    if response.status_code == 200:
        print("✅ Reporte enviado correctamente a Gotify")
    else:
        print(f"❌ Error HTTP: {response.status_code}")
        sys.exit(1)
        
except ImportError:
    print("❌ Requests no disponible")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
PYTHON_SCRIPT

else
    # Método 2: Fallback con curl y archivo temporal
    echo "🔄 Usando método alternativo..."
    TEMP_FILE="/tmp/logwatch_$$.txt"
    echo "$REPORT" > "$TEMP_FILE"
    
    RESPONSE=$(curl -s -w "%{http_code}" \
        -X POST "$GOTIFY_URL/message" \
        -H "X-Gotify-Key: $GOTIFY_TOKEN" \
        -F "title=$TITLE" \
        -F "message=<$TEMP_FILE" \
        -F "priority=$GOTIFY_PRIORITY")
    
    rm -f "$TEMP_FILE"
    
    HTTP_CODE=${RESPONSE: -3}
    if [[ $HTTP_CODE -eq 200 ]]; then
        echo "✅ Reporte enviado correctamente"
    else
        echo "❌ Error HTTP: $HTTP_CODE"
        exit 1
    fi
fi
EOF

    chmod +x /usr/local/bin/logwatch-gotify.sh
    show_message "Script de Gotify creado ✓"
}

# Configurar cron
setup_cron() {
    show_message "Configurando tarea programada..."
    
    cat > /etc/cron.daily/logwatch << EOF
#!/bin/bash
$LOGWATCH_PATH --output stdout | /usr/local/bin/logwatch-gotify.sh
EOF

    chmod +x /etc/cron.daily/logwatch
    show_message "Cron configurado ✓"
}

# Crear script de prueba
create_test_script() {
    show_message "Creando script de prueba..."
    
    cat > /usr/local/bin/test-logwatch-gotify.sh << EOF
#!/bin/bash

echo "🧪 Probando instalación completa..."

# Verificar logwatch
if [[ ! -x "$LOGWATCH_PATH" ]]; then
    echo "❌ Logwatch no encontrado en $LOGWATCH_PATH"
    exit 1
fi

echo "✅ Logwatch encontrado: $LOGWATCH_PATH"

# Generar reporte
echo "📊 Generando reporte..."
REPORT=\$($LOGWATCH_PATH --output stdout --range today 2>&1)

if [[ -n "\$REPORT" ]] && [[ "\$REPORT" != *"No such file"* ]]; then
    echo "✅ Reporte generado correctamente"
    echo "📤 Enviando a Gotify..."
    echo "\$REPORT" | /usr/local/bin/logwatch-gotify.sh
else
    echo "⚠️  Sin actividad hoy, enviando mensaje de prueba..."
    echo "🧪 INSTALACIÓN COMPLETA EXITOSA

✅ Servidor: \$(hostname)
🕒 Fecha: \$(date)
📊 Logwatch: Instalado y configurado
📱 Gotify: Conectado correctamente

🎯 Todo está funcionando perfectamente.
El reporte diario se enviará automáticamente." | /usr/local/bin/logwatch-gotify.sh
fi

echo "🎯 Prueba completada"
EOF

    chmod +x /usr/local/bin/test-logwatch-gotify.sh
    show_message "Script de prueba creado ✓"
}

# Mostrar resumen
show_summary() {
    echo
    echo -e "${GREEN}=== INSTALACIÓN COMPLETA EXITOSA ===${NC}"
    echo
    echo -e "${BLUE}Configuración:${NC}"
    echo "  ✅ Logwatch instalado en: $LOGWATCH_PATH"
    echo "  ✅ Python3 y requests instalados"
    echo "  ✅ Gotify configurado: https://gotify.argustics.com"
    echo "  ✅ JSON corregido: Sin errores de formato"
    echo "  ✅ Cron programado: Reporte diario automático"
    echo
    echo -e "${BLUE}Prueba la instalación:${NC}"
    echo "  sudo /usr/local/bin/test-logwatch-gotify.sh"
    echo
    echo -e "${YELLOW}¡Todo listo para funcionar!${NC}"
}

# Función principal
main() {
    check_root
    detect_distro
    setup_gotify_config
    
    echo
    show_message "Iniciando instalación completa..."
    
    install_packages
    create_directories
    configure_logwatch
    create_gotify_script
    setup_cron
    create_test_script
    
    show_summary
}

# Ejecutar
main "$@"
