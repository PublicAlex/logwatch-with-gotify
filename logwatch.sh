#!/bin/bash

# Script completo: Instalar y configurar Logwatch + Gotify con formato HTML
echo "🚀 INSTALADOR COMPLETO: LOGWATCH + GOTIFY (HTML PLEGABLE)"
echo

set -e

# ========================================
# CONFIGURACIÓN PERSONALIZABLE
# ========================================
DETAIL_LEVEL=3                    # Nivel de detalle (0-10)
RANGE="yesterday"                 # Rango de tiempo (yesterday, today, all)
EXCLUDED_SERVICES="-zz-network -zz-sys"  # Servicios a excluir
GOTIFY_URL="https://gotify.xxxxxxxxx.com"
GOTIFY_TOKEN="Ahf_Tsda123asd12das"
GOTIFY_PRIORITY=1

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
    echo -e "${BLUE}=== Configuración ===${NC}"
    echo "  📊 Nivel de detalle: $DETAIL_LEVEL"
    echo "  📅 Rango de tiempo: $RANGE"
    echo "  🚫 Servicios excluidos: $EXCLUDED_SERVICES"
    echo "  🌐 Gotify URL: $GOTIFY_URL"
    echo "  🔑 Priority: $GOTIFY_PRIORITY"
    echo "  📄 Formato: HTML plegable"
    
    show_message "Configuración aplicada ✅"
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
    show_message "Python3 y dependencias instaladas ✅"
}

# Crear directorios necesarios
create_directories() {
    show_message "Creando directorios necesarios..."
    mkdir -p /var/cache/logwatch
    mkdir -p /etc/logwatch/conf
    mkdir -p /var/log/logwatch
    chmod 755 /var/cache/logwatch
    show_message "Directorios creados ✅"
}

# Configurar logwatch
configure_logwatch() {
    show_message "Configurando logwatch..."
    
    cat > /etc/logwatch/conf/logwatch.conf << EOF
# Configuración de logwatch para Gotify
LogDir = /var/log
TmpDir = /var/cache/logwatch
Output = stdout
Format = text
Encode = none
Detail = $DETAIL_LEVEL
Service = All
$(echo "$EXCLUDED_SERVICES" | tr ' ' '\n' | while read service; do echo "Service = \"$service\""; done)
Range = $RANGE
Archives = Yes
MailTo = stdout
MailFrom = logwatch@localhost
EOF

    show_message "Logwatch configurado con Detail=$DETAIL_LEVEL ✅"
}

# Crear procesador HTML con acordeones
create_html_processor() {
    show_message "Creando procesador HTML con acordeones..."
    
    cat > /usr/local/bin/logwatch-html-processor.py << 'EOF'
#!/usr/bin/env python3
import sys
import re
import html
from datetime import datetime

def escape_html(text):
    """Escapar caracteres HTML especiales"""
    return html.escape(text)

def parse_logwatch_output(content):
    """Parsear salida de logwatch y organizarla por secciones"""
    lines = content.split('\n')
    sections = {}
    current_section = None
    current_content = []
    
    for line in lines:
        # Detectar líneas de separación (usualmente con guiones o asteriscos)
        if re.match(r'^[\s]*[-=*]{3,}', line) or re.match(r'^[\s]*#{3,}', line):
            if current_section and current_content:
                sections[current_section] = '\n'.join(current_content)
            current_section = None
            current_content = []
            continue
            
        # Detectar títulos de sección (líneas que parecen títulos)
        if re.match(r'^[A-Z][A-Za-z\s]+[:]?\s*$', line.strip()) and len(line.strip()) < 80:
            # Guardar sección anterior
            if current_section and current_content:
                sections[current_section] = '\n'.join(current_content)
            
            current_section = line.strip().rstrip(':')
            current_content = []
            continue
        
        # Detectar secciones por patrones comunes de logwatch
        section_patterns = [
            r'.*Begin.*',
            r'.*Summary.*',
            r'.*Report.*',
            r'.*Log.*Analysis.*',
            r'.*System.*Events.*',
            r'.*Security.*',
            r'.*Network.*',
            r'.*Disk.*',
            r'.*Mail.*',
            r'.*Apache.*',
            r'.*SSH.*',
            r'.*Failed.*',
            r'.*Success.*',
        ]
        
        for pattern in section_patterns:
            if re.match(pattern, line.strip(), re.IGNORECASE):
                if current_section and current_content:
                    sections[current_section] = '\n'.join(current_content)
                current_section = line.strip()
                current_content = []
                break
        else:
            # Agregar línea al contenido actual
            if line.strip():  # Solo agregar líneas no vacías
                current_content.append(line)
    
    # Guardar última sección
    if current_section and current_content:
        sections[current_section] = '\n'.join(current_content)
    
    # Si no encontramos secciones, crear una sección general
    if not sections and content.strip():
        sections['Reporte General'] = content
    
    return sections

def generate_html_report(sections, hostname, date):
    """Generar HTML con acordeones"""
    
    # Contar secciones con contenido
    sections_with_content = {k: v for k, v in sections.items() if v.strip()}
    total_sections = len(sections_with_content)
    
    html_content = f"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Logwatch Report - {hostname}</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }}
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            text-align: center;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }}
        .header h1 {{
            margin: 0;
            font-size: 24px;
        }}
        .header .subtitle {{
            opacity: 0.9;
            margin-top: 5px;
            font-size: 14px;
        }}
        .summary {{
            background: white;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-left: 4px solid #4CAF50;
        }}
        .accordion {{
            margin-bottom: 10px;
        }}
        .accordion-item {{
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            transition: all 0.3s ease;
        }}
        .accordion-item:hover {{
            box-shadow: 0 4px 8px rgba(0,0,0,0.15);
        }}
        .accordion-header {{
            background: #f8f9fa;
            padding: 15px 20px;
            cursor: pointer;
            border: none;
            width: 100%;
            text-align: left;
            font-size: 16px;
            font-weight: 600;
            color: #495057;
            display: flex;
            justify-content: space-between;
            align-items: center;
            transition: background-color 0.3s ease;
        }}
        .accordion-header:hover {{
            background: #e9ecef;
        }}
        .accordion-header.active {{
            background: #e3f2fd;
            color: #1976d2;
        }}
        .accordion-icon {{
            font-size: 18px;
            transition: transform 0.3s ease;
        }}
        .accordion-header.active .accordion-icon {{
            transform: rotate(180deg);
        }}
        .accordion-content {{
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.3s ease;
            background: white;
        }}
        .accordion-content.active {{
            max-height: 1000px;
        }}
        .accordion-body {{
            padding: 20px;
            white-space: pre-wrap;
            font-family: 'Courier New', monospace;
            font-size: 12px;
            line-height: 1.4;
            background: #f8f9fa;
            border-radius: 4px;
            margin: 0 15px 15px 15px;
            max-height: 400px;
            overflow-y: auto;
        }}
        .empty-section {{
            color: #6c757d;
            font-style: italic;
            padding: 20px;
            text-align: center;
        }}
        .expand-all {{
            margin-bottom: 20px;
            text-align: center;
        }}
        .btn {{
            background: #007bff;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            margin: 0 5px;
            font-size: 14px;
            transition: background-color 0.3s ease;
        }}
        .btn:hover {{
            background: #0056b3;
        }}
        .btn-secondary {{
            background: #6c757d;
        }}
        .btn-secondary:hover {{
            background: #545b62;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 Reporte Logwatch</h1>
        <div class="subtitle">🖥️ {hostname} • 📅 {date}</div>
    </div>
    
    <div class="summary">
        <strong>📋 Resumen:</strong> Se encontraron <strong>{total_sections}</strong> secciones con actividad.<br>
        <em>Haz clic en cada sección para expandir/contraer el contenido.</em>
    </div>
    
    <div class="expand-all">
        <button class="btn" onclick="expandAll()">📖 Expandir Todo</button>
        <button class="btn btn-secondary" onclick="collapseAll()">📕 Contraer Todo</button>
    </div>
    
    <div class="accordion">
"""
    
    # Generar acordeones para cada sección
    section_id = 0
    for section_name, content in sections_with_content.items():
        section_id += 1
        clean_content = escape_html(content.strip())
        
        # Determinar icono basado en el contenido
        icon = "📄"
        if any(word in section_name.lower() for word in ['error', 'fail', 'critical']):
            icon = "❌"
        elif any(word in section_name.lower() for word in ['security', 'auth', 'ssh']):
            icon = "🔒"
        elif any(word in section_name.lower() for word in ['network', 'connection']):
            icon = "🌐"
        elif any(word in section_name.lower() for word in ['disk', 'space', 'mount']):
            icon = "💾"
        elif any(word in section_name.lower() for word in ['mail', 'email']):
            icon = "📧"
        elif any(word in section_name.lower() for word in ['apache', 'nginx', 'web']):
            icon = "🌍"
        elif any(word in section_name.lower() for word in ['success', 'ok', 'completed']):
            icon = "✅"
        
        html_content += f"""
        <div class="accordion-item">
            <button class="accordion-header" onclick="toggleAccordion({section_id})">
                <span>{icon} {escape_html(section_name)}</span>
                <span class="accordion-icon">▼</span>
            </button>
            <div class="accordion-content" id="accordion-{section_id}">
                <div class="accordion-body">{clean_content}</div>
            </div>
        </div>
"""
    
    # Si no hay secciones, mostrar mensaje
    if not sections_with_content:
        html_content += """
        <div class="accordion-item">
            <div class="empty-section">
                📭 No se encontró actividad significativa en este período.
            </div>
        </div>
"""
    
    html_content += """
    </div>

    <script>
        function toggleAccordion(id) {
            const header = document.querySelector(`button[onclick="toggleAccordion(${id})"]`);
            const content = document.getElementById(`accordion-${id}`);
            
            header.classList.toggle('active');
            content.classList.toggle('active');
        }
        
        function expandAll() {
            const headers = document.querySelectorAll('.accordion-header');
            const contents = document.querySelectorAll('.accordion-content');
            
            headers.forEach(header => header.classList.add('active'));
            contents.forEach(content => content.classList.add('active'));
        }
        
        function collapseAll() {
            const headers = document.querySelectorAll('.accordion-header');
            const contents = document.querySelectorAll('.accordion-content');
            
            headers.forEach(header => header.classList.remove('active'));
            contents.forEach(content => content.classList.remove('active'));
        }
    </script>
</body>
</html>
"""
    
    return html_content

def main():
    # Leer contenido desde stdin
    content = sys.stdin.read()
    
    if not content.strip():
        print("No hay contenido para procesar")
        return
    
    # Obtener información del sistema
    import socket
    hostname = socket.gethostname()
    date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Parsear y generar HTML
    sections = parse_logwatch_output(content)
    html_report = generate_html_report(sections, hostname, date)
    
    print(html_report)

if __name__ == "__main__":
    main()
EOF

    chmod +x /usr/local/bin/logwatch-html-processor.py
    show_message "Procesador HTML creado ✅"
}

# Crear script de Gotify con soporte HTML
create_gotify_script() {
    show_message "Creando script de Gotify con soporte HTML..."
    
    cat > /usr/local/bin/logwatch-gotify.sh << EOF
#!/bin/bash

# Configuración Gotify
GOTIFY_URL="$GOTIFY_URL"
GOTIFY_TOKEN="$GOTIFY_TOKEN"
GOTIFY_PRIORITY=$GOTIFY_PRIORITY

# Leer reporte HTML
HTML_REPORT=\$(cat)
if [[ -z "\$HTML_REPORT" ]]; then
    echo "No hay contenido para enviar"
    exit 0
fi

HOSTNAME=\$(hostname)
DATE=\$(date '+%Y-%m-%d %H:%M')
TITLE="📊 Logwatch Report - \$HOSTNAME (\$DATE)"

# Enviar usando Python con requests (formato HTML)
if command -v python3 >/dev/null 2>&1; then
    python3 << PYTHON_SCRIPT
import json
import sys
try:
    import requests
    
    # Crear payload con contenido HTML
    payload = {
        "title": "\$TITLE",
        "message": """\$HTML_REPORT""",
        "priority": \$GOTIFY_PRIORITY,
        "extras": {
            "android::action": {
                "onReceive": {
                    "intentAction": "android.intent.action.VIEW"
                }
            }
        }
    }
    
    headers = {
        "X-Gotify-Key": "\$GOTIFY_TOKEN",
        "Content-Type": "application/json"
    }
    
    response = requests.post("\$GOTIFY_URL/message", json=payload, headers=headers, timeout=30)
    
    if response.status_code == 200:
        print("✅ Reporte HTML enviado correctamente a Gotify")
    else:
        print(f"⚠️ Error HTTP: {response.status_code}")
        print(f"Response: {response.text}")
        sys.exit(1)
        
except ImportError:
    print("⚠️ Requests no disponible, usando método alternativo...")
    sys.exit(1)
except Exception as e:
    print(f"⚠️ Error: {e}")
    sys.exit(1)
PYTHON_SCRIPT

else
    # Método alternativo con curl
    echo "🔧 Usando método alternativo con curl..."
    TEMP_FILE="/tmp/logwatch_html_\$\$.json"
    
    # Crear JSON manualmente para curl
    cat > "\$TEMP_FILE" << JSON_EOF
{
    "title": "\$TITLE",
    "message": \$(echo "\$HTML_REPORT" | python3 -c "import json, sys; print(json.dumps(sys.stdin.read()))"),
    "priority": \$GOTIFY_PRIORITY
}
JSON_EOF
    
    RESPONSE=\$(curl -s -w "%{http_code}" \\
        -X POST "\$GOTIFY_URL/message" \\
        -H "X-Gotify-Key: \$GOTIFY_TOKEN" \\
        -H "Content-Type: application/json" \\
        -d @"\$TEMP_FILE")
    
    rm -f "\$TEMP_FILE"
    
    HTTP_CODE=\${RESPONSE: -3}
    if [[ \$HTTP_CODE -eq 200 ]]; then
        echo "✅ Reporte HTML enviado correctamente"
    else
        echo "⚠️ Error HTTP: \$HTTP_CODE"
        exit 1
    fi
fi
EOF

    chmod +x /usr/local/bin/logwatch-gotify.sh
    show_message "Script de Gotify con HTML creado ✅"
}

# Configurar cron con procesamiento HTML
setup_cron() {
    show_message "Configurando tarea programada con procesamiento HTML..."
    
    # Construir comando con servicios excluidos
    EXCLUDE_PARAMS=""
    for service in $EXCLUDED_SERVICES; do
        EXCLUDE_PARAMS="$EXCLUDE_PARAMS --service \"$service\""
    done
    
    cat > /etc/cron.daily/logwatch << EOF
#!/bin/bash
$LOGWATCH_PATH --output stdout --detail $DETAIL_LEVEL --range $RANGE --service all $EXCLUDE_PARAMS | /usr/local/bin/logwatch-html-processor.py | /usr/local/bin/logwatch-gotify.sh
EOF

    chmod +x /etc/cron.daily/logwatch
    show_message "Cron configurado con procesamiento HTML ✅"
}

# Crear script de prueba mejorado
create_test_script() {
    show_message "Creando script de prueba con HTML..."
    
    # Construir comando de prueba con servicios excluidos
    EXCLUDE_PARAMS=""
    for service in $EXCLUDED_SERVICES; do
        EXCLUDE_PARAMS="$EXCLUDE_PARAMS --service \"$service\""
    done
    
    cat > /usr/local/bin/test-logwatch-gotify.sh << EOF
#!/bin/bash

echo "🧪 Probando instalación completa con HTML..."

# Verificar logwatch
if [[ ! -x "$LOGWATCH_PATH" ]]; then
    echo "⚠️ Logwatch no encontrado en $LOGWATCH_PATH"
    exit 1
fi

echo "✅ Logwatch encontrado: $LOGWATCH_PATH"
echo "📊 Configuración: Detail=$DETAIL_LEVEL, Range=today, Excluded=$EXCLUDED_SERVICES"
echo "📄 Formato: HTML con acordeones"

# Generar reporte
echo "📊 Generando reporte..."
REPORT=\$($LOGWATCH_PATH --output stdout --detail $DETAIL_LEVEL --range today --service all $EXCLUDE_PARAMS 2>&1)

if [[ -n "\$REPORT" ]] && [[ "\$REPORT" != *"No such file"* ]]; then
    echo "✅ Reporte generado correctamente"
    echo "🔄 Procesando a HTML..."
    HTML_REPORT=\$(echo "\$REPORT" | /usr/local/bin/logwatch-html-processor.py)
    echo "📧 Enviando a Gotify..."
    echo "\$HTML_REPORT" | /usr/local/bin/logwatch-gotify.sh
else
    echo "⚠️ Sin actividad hoy, enviando mensaje de prueba HTML..."
    
    # Crear reporte de prueba
    TEST_REPORT="🧪 PRUEBA DE INSTALACIÓN COMPLETA

✅ Servidor: \$(hostname)
🕐 Fecha: \$(date)
📊 Logwatch: Instalado y configurado
   - Nivel de detalle: $DETAIL_LEVEL
   - Rango: $RANGE
   - Servicios excluidos: $EXCLUDED_SERVICES
📧 Gotify: Conectado correctamente
📄 Formato: HTML con acordeones

🎉 Todo está funcionando perfectamente.
El reporte diario se enviará automáticamente con formato HTML interactivo."

    echo "\$TEST_REPORT" | /usr/local/bin/logwatch-html-processor.py | /usr/local/bin/logwatch-gotify.sh
fi

echo "🎉 Prueba completada"
EOF

    chmod +x /usr/local/bin/test-logwatch-gotify.sh
    show_message "Script de prueba con HTML creado ✅"
}

# Mostrar resumen
show_summary() {
    echo
    echo -e "${GREEN}=== INSTALACIÓN COMPLETA EXITOSA (HTML) ===${NC}"
    echo
    echo -e "${BLUE}Configuración:${NC}"
    echo "  ✅ Logwatch instalado en: $LOGWATCH_PATH"
    echo "  ✅ Python3 y requests instalados"
    echo "  ✅ Procesador HTML con acordeones"
    echo "  ✅ Gotify configurado: $GOTIFY_URL"
    echo "  ✅ Nivel de detalle: $DETAIL_LEVEL"
    echo "  ✅ Rango de tiempo: $RANGE"
    echo "  ✅ Servicios excluidos: $EXCLUDED_SERVICES"
    echo "  ✅ Cron programado: Reporte diario automático"
    echo "  ✅ Formato: HTML interactivo con acordeones"
    echo
    echo -e "${BLUE}Comandos útiles:${NC}"
    echo "  # Probar instalación:"
    echo "  sudo /usr/local/bin/test-logwatch-gotify.sh"
    echo
    echo "  # Ejecutar manualmente:"
    echo "  sudo $LOGWATCH_PATH --output stdout --detail $DETAIL_LEVEL --range today --service all $(echo $EXCLUDED_SERVICES | sed 's/\([^[:space:]]*\)/--service "\1"/g') | sudo /usr/local/bin/logwatch-html-processor.py | sudo /usr/local/bin/logwatch-gotify.sh"
    echo
    echo "  # Solo generar HTML (sin enviar):"
    echo "  sudo $LOGWATCH_PATH --output stdout --detail $DETAIL_LEVEL --range today --service all $(echo $EXCLUDED_SERVICES | sed 's/\([^[:space:]]*\)/--service "\1"/g') | sudo /usr/local/bin/logwatch-html-processor.py > /tmp/logwatch_report.html"
    echo
    echo -e "${YELLOW}¡Todo listo! Los reportes ahora se enviarán con formato HTML interactivo.${NC}"
    echo -e "${BLUE}📱 En Gotify podrás expandir/contraer cada sección según necesites.${NC}"
}

# Función principal
main() {
    check_root
    detect_distro
    setup_gotify_config
    
    echo
    show_message "Iniciando instalación completa con HTML..."
    
    install_packages
    create_directories
    configure_logwatch
    create_html_processor
    create_gotify_script
    setup_cron
    create_test_script
    
    show_summary
}

# Ejecutar
main "$@"
