# 📊 Logwatch + Gotify HTML Reporter

> **Proyecto Personal** - Desarrollado para automatizar reportes de sistema con interfaz HTML interactiva

## 🚨 **REQUISITO IMPORTANTE: Gotify Plus**

⚠️ **Para visualizar correctamente los reportes HTML desde tu dispositivo Android, necesitas usar [Gotify Plus](https://play.google.com/store/apps/details?id=com.github.gotify.plus) en lugar de la aplicación estándar de Gotify.**

**¿Por qué Gotify Plus?**
- ✅ **Renderiza HTML** correctamente en los mensajes
- ✅ **Soporte para acordeones** y JavaScript
- ✅ **Interfaz responsive** que se adapta al móvil
- ❌ La app estándar de Gotify **NO puede mostrar HTML**, solo texto plano

---

## 🎯 **¿Qué hace este proyecto?**

Este script automatiza la generación y envío de reportes diarios de sistema usando **Logwatch** con una interfaz HTML moderna y interactiva. En lugar de recibir reportes de texto plano aburridos, obtienes:

### 📱 **Vista en Gotify Plus:**
- 🎨 **Acordeones interactivos** - Expande solo las secciones que te interesan
- 📊 **Categorización automática** - Errores, seguridad, red, etc.
- 🎯 **Vista compacta** - Todo colapsado por defecto
- 📍 **Navegación fácil** - Botones para expandir/contraer todo
- 🔍 **Iconos contextuales** - Identificación visual rápida

### 🖥️ **En el servidor:**
- 🔄 **Ejecución automática** diaria via cron
- ⚙️ **Configuración personalizable** (nivel de detalle, rangos, etc.)
- 🛠️ **Scripts de debug** incluidos
- ⏱️ **Timeouts inteligentes** para evitar cuelgues

---

## 🚀 **Instalación Rápida**

### 1. **Preparar el script:**
```bash
# Descargar o crear el archivo del script
nano logwatch-gotify-html.sh

# Hacer ejecutable
chmod +x logwatch-gotify-html.sh
```

### 2. **Configurar variables:**
Edita estas líneas al inicio del script:
```bash
GOTIFY_URL="https://tu-gotify-server.com"    # 🌐 Tu servidor Gotify
GOTIFY_TOKEN="tu_token_aqui"                 # 🔑 Tu token de aplicación
GOTIFY_PRIORITY=1                            # 📮 Prioridad de mensajes
DETAIL_LEVEL=3                               # 📊 Nivel de detalle (0-10)
RANGE="yesterday"                            # 📅 Rango (yesterday/today/all)
```

### 3. **Ejecutar instalación:**
```bash
sudo ./logwatch-gotify-html.sh
```

### 4. **Probar funcionamiento:**
```bash
sudo /usr/local/bin/test-logwatch-gotify.sh
```

---

## 📱 **Configuración de Gotify Plus**

### **Android:**
1. 📲 Instala **Gotify Plus** desde Play Store
2. ➕ Agrega tu servidor Gotify
3. 🔑 Usa tu token de cliente (no el de aplicación)
4. ✅ Los mensajes HTML se renderizarán automáticamente

### **Servidor Gotify:**
1. 🔧 Crea una nueva aplicación en tu panel de Gotify
2. 📋 Copia el token generado
3. 🔄 Úsalo en la variable `GOTIFY_TOKEN` del script

---

## 🛠️ **Comandos Útiles**

### **Mantenimiento:**
```bash
# 🧪 Probar instalación completa
sudo /usr/local/bin/test-logwatch-gotify.sh

# 🔍 Debug si hay problemas
sudo /usr/local/bin/debug-logwatch.sh

# 📊 Ejecutar reporte manual
sudo timeout 60 /usr/sbin/logwatch --output stdout --detail 3 --range today --service all | sudo /usr/local/bin/logwatch-html-processor.py | sudo /usr/local/bin/logwatch-gotify.sh

# 📄 Solo generar HTML (para revisar)
sudo timeout 60 /usr/sbin/logwatch --output stdout --detail 3 --range today --service all | sudo /usr/local/bin/logwatch-html-processor.py > /tmp/logwatch_report.html
```

### **Ver reportes generados:**
```bash
# 📝 Ver el HTML generado en navegador
firefox /tmp/logwatch_report.html

# 📋 Ver logs del cron
sudo journalctl -u cron | grep logwatch
```

---

## ⚙️ **Personalización**

### **Niveles de Detalle:**
- `0-2`: 📄 Básico - Solo errores críticos
- `3-5`: 📊 Intermedio - Errores + warnings importantes  
- `6-8`: 📈 Detallado - Incluye más actividad del sistema
- `9-10`: 🔍 Completo - Toda la actividad registrada

### **Rangos de Tiempo:**
- `today`: 📅 Solo hoy
- `yesterday`: 📅 Solo ayer (recomendado para cron diario)
- `all`: 📅 Todos los logs disponibles

### **Modificar horario del cron:**
```bash
# Editar cron para cambiar horario
sudo nano /etc/cron.daily/logwatch

# O mover a cron.hourly para reportes por hora
sudo mv /etc/cron.daily/logwatch /etc/cron.hourly/
```

---

## 🐛 **Solución de Problemas**

### **El script se cuelga:**
```bash
# Ejecutar debug
sudo /usr/local/bin/debug-logwatch.sh

# Probar logwatch manualmente
sudo logwatch --print --range yesterday --detail 1
```

### **No llegan mensajes a Gotify:**
```bash
# Verificar conectividad
curl -X POST "https://tu-servidor.com/message" \
     -H "X-Gotify-Key: tu_token" \
     -F "title=Test" \
     -F "message=Test message"

# Verificar logs
sudo tail -f /var/log/syslog | grep logwatch
```

### **HTML no se ve bien:**
- ✅ **Verifica que usas Gotify Plus** (no la app estándar)
- 🔍 Revisa que el token sea correcto
- 📱 Actualiza Gotify Plus a la última versión

---

## 📁 **Estructura de Archivos**

```
/usr/local/bin/
├── 📄 logwatch-html-processor.py     # Generador de HTML
├── 📧 logwatch-gotify.sh            # Envío a Gotify
├── 🧪 test-logwatch-gotify.sh       # Script de prueba
└── 🔍 debug-logwatch.sh             # Debugging

/etc/
├── 📁 logwatch/conf/logwatch.conf   # Configuración Logwatch
└── 📁 cron.daily/logwatch           # Tarea programada
```

---

## 🔄 **Automatización**

Una vez instalado, el sistema funciona completamente automático:

1. 🕘 **Cada día** el cron ejecuta logwatch
2. 📊 **Genera** un reporte del día anterior  
3. 🎨 **Convierte** a HTML con acordeones
4. 📱 **Envía** a Gotify Plus
5. ✅ **Recibes** notificación interactiva

---

## 📋 **Compatibilidad**

### **Sistemas Operativos:**
- ✅ Ubuntu/Debian
- ✅ CentOS/RHEL  
- ✅ Arch Linux
- ✅ Otros derivados de Linux

### **Dependencias:**
- 📦 `logwatch`
- 🐍 `python3` + `requests`
- 🌐 `curl`
- 📡 Servidor Gotify funcionando
- 📱 Gotify Plus en Android

---

## 🤝 **Contribuciones**

Este es un **proyecto personal** desarrollado para mis necesidades específicas de monitoreo. 

Si tienes sugerencias o mejoras:
- 🐛 Reporta bugs via issues
- 💡 Comparte ideas de mejoras  
- 🔧 Los PRs son bienvenidos

---

## 📜 **Licencia**

**Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)**

### ✅ **Permitido:**
- ✅ **Uso personal** y no comercial
- ✅ **Modificación** y adaptación del código
- ✅ **Distribución** con atribución adecuada
- ✅ **Aprendizaje** y uso educativo

### ❌ **NO Permitido:**
- ❌ **Uso comercial** de cualquier tipo
- ❌ **Servicios empresariales** basados en este código
- ❌ **Monetización directa o indirecta** sin autorización

### 📋 **Términos:**
- **Atribución requerida**: Debe creditarse al autor original
- **Uso no comercial únicamente**: Sin fines de lucro
- **Misma licencia**: Obras derivadas deben usar la misma licencia
- **Sin garantías**: El software se proporciona "tal como está"

### 💼 **Para Uso Empresarial:**
Si representas una empresa y deseas usar este software comercialmente:
- 📧 **Contacta para licenciamiento comercial separado**
- 💰 **Licencia dual disponible** bajo términos comerciales
- 🤝 **Soporte y personalización** disponibles para clientes comerciales

---

**Licencia Completa:** https://creativecommons.org/licenses/by-nc/4.0/

**Resumen:** Proyecto bajo licencia Creative Commons no comercial - libre para uso personal, restringido para uso empresarial.

---

## 📞 **Soporte**

Si tienes problemas:

1. 🔍 Ejecuta `sudo /usr/local/bin/debug-logwatch.sh`
2. 📋 Revisa los logs: `sudo journalctl -u cron`
3. 🧪 Prueba: `sudo /usr/local/bin/test-logwatch-gotify.sh`
4. 📱 Verifica que usas **Gotify Plus**, no la app estándar

**¡Disfruta de tus reportes de sistema con estilo!** 🎉

---

> 💡 **Tip Pro:** Ajusta el `DETAIL_LEVEL` según tus necesidades. Nivel 3 es perfecto para la mayoría de casos - suficiente información sin spam.
