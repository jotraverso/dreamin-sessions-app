# 📊 Session Import Tool - Guía de Uso

Herramienta para convertir el archivo `sessions.xlsx` a CSV compatible con Salesforce.

## 🚀 Instalación

```bash
# Activar el entorno virtual
source ../.venv/bin/activate

# Instalar dependencias
pip install -r requirements-sessions.txt
```

## 📝 Uso Básico

### Generar CSV Normal

```bash
python generate_sessions_csv.py <CAMPAIGN_ID>
```

**Ejemplo:**

```bash
python generate_sessions_csv.py 701RR00000vcS9yYAE
```

Esto genera `sessions_import.csv` con todos los datos reales.

### Generar CSV Anonimizado

```bash
python generate_sessions_csv.py <CAMPAIGN_ID> --anon
```

**Ejemplo:**

```bash
python generate_sessions_csv.py 701RR00000vcS9yYAE --anon --output sessions_anon.csv
```

Esto anonimiza:

- ✅ Nombres de speakers (primarios y co-speakers)
- ✅ Emails
- ✅ URLs de LinkedIn

## 🔧 Opciones Disponibles

```
--config CONFIG   Archivo de configuración YAML (default: session-mapping.yml)
--input INPUT     Archivo Excel de entrada (default: sessions.xlsx)
--output OUTPUT   Archivo CSV de salida (default: sessions_import.csv)
--anon           Anonimizar datos PII
```

## 📋 Campos Mapeados

El archivo `session-mapping.yml` define el mapeo de columnas:

| Columna Excel            | Campo Salesforce            |
| ------------------------ | --------------------------- |
| Session Title            | `Title__c`                  |
| Session Abstract         | `Abstract__c`               |
| First Name and Last Name | `PrimarySpeakerName__c`     |
| Email address            | `PrimarySpeakerEmail__c`    |
| Your LinkedIn            | `PrimarySpeakerBio__c`      |
| Main Role                | `PrimarySpeakerJobTitle__c` |
| Second Speaker info      | `CoSpeakerName__c`          |
| Second Speaker Email     | `CoSpeakerEmail__c`         |
| Main Product             | `Product__c`                |
| Session Language         | `Language__c`               |
| Session length           | `DurationMinutes__c`        |
| Session Level            | `Level__c`                  |
| Link with slides         | `SessionLink__c`            |
| Anything else            | `SomethingElse__c`          |
| Timestamp                | `SubmissionDateTime__c`     |

## 🔒 Datos PII Anonimizados

Cuando se usa `--anon`, se generan datos ficticios usando la librería Faker:

**Datos Originales:**

```
Omar Ghachy, omar.ghachy@gmail.com
```

**Datos Anonimizados:**

```
Allison Hill, john39@example.org
```

✅ **Consistencia garantizada:** Si una persona aparece en múltiples sesiones, mantendrá el mismo nombre/email ficticio.

## 📦 Importación en Salesforce

1. Generar el CSV con el Campaign ID correcto
2. Abrir Data Loader o Data Import Wizard
3. Seleccionar objeto: `Session__c`
4. Mapear campos automáticamente (los nombres API coinciden)
5. Importar

## ⚠️ Notas Importantes

- El Campaign ID es **obligatorio** y debe ser válido (empezar con `701` y tener 15 o 18 caracteres)
- El encoding es **UTF-8** para preservar caracteres especiales
- Los datos se limpian automáticamente (espacios, saltos de línea)
