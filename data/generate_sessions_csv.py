#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para convertir sessions.xlsx a CSV con nombres API de Salesforce
Usa el archivo session-mapping.yml para el mapeo de columnas

Uso:
    python generate_sessions_csv.py <CAMPAIGN_ID> [--anon]

Ejemplo:
    python generate_sessions_csv.py 701XXXXXXXXXXXXXXX
    python generate_sessions_csv.py 701XXXXXXXXXXXXXXX --anon
"""
import pandas as pd
import yaml
import re
from datetime import datetime
import sys
import argparse
from faker import Faker


def load_config(config_file="session-mapping.yml"):
    """Carga la configuración YAML"""
    with open(config_file, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def transform_duration(value):
    """Convierte '30 minutes' o '60 minutes' a número"""
    if pd.isna(value) or value == "":
        return None

    # Buscar el patrón de número seguido de "minutes" o "minute"
    match = re.search(r"(\d+)\s*minutes?", str(value), re.IGNORECASE)
    if match:
        return int(match.group(1))

    # Si ya es un número, devolverlo
    try:
        return int(value)
    except (ValueError, TypeError):
        return None


def transform_datetime(value, date_format="%Y-%m-%d %H:%M:%S"):
    """Convierte datetime a formato ISO para Salesforce"""
    if pd.isna(value):
        return None

    # Si ya es un objeto datetime de pandas
    if isinstance(value, pd.Timestamp):
        # Formato ISO 8601 para Salesforce: YYYY-MM-DDTHH:MM:SS.sssZ
        return value.strftime("%Y-%m-%dT%H:%M:%S.000Z")

    # Si es string, intentar parsearlo
    try:
        dt = datetime.strptime(str(value), date_format)
        return dt.strftime("%Y-%m-%dT%H:%M:%S.000Z")
    except (ValueError, TypeError):
        return None


def transform_value(value, field_config):
    """Aplica transformaciones según la configuración"""
    if field_config is None:
        return value

    transform_type = field_config.get("type")

    if transform_type == "duration_to_number":
        return transform_duration(value)
    elif transform_type == "integer":
        if pd.isna(value) or value == "":
            return None
        try:
            return int(value)
        except (ValueError, TypeError):
            return None
    elif transform_type == "datetime":
        date_format = field_config.get("format", "%Y-%m-%d %H:%M:%S")
        return transform_datetime(value, date_format)
    elif transform_type == "truncate":
        if pd.isna(value) or value == "":
            return value
        max_length = field_config.get("max_length", 255)
        value_str = str(value)
        if len(value_str) > max_length:
            return value_str[:max_length]
        return value_str

    return value


def clean_value(value):
    """Limpia y normaliza valores para CSV"""
    if pd.isna(value) or value is None:
        return ""

    # Convertir a string y limpiar
    value_str = str(value).strip()

    # Reemplazar saltos de línea por espacios para evitar problemas en CSV
    value_str = value_str.replace("\n", " ").replace("\r", " ")

    # Normalizar espacios múltiples
    value_str = re.sub(r"\s+", " ", value_str)

    return value_str


def anonymize_data(df, pii_config, seed=42):
    """
    Anonimiza los datos PII del DataFrame usando Faker

    Args:
        df: DataFrame a anonimizar
        pii_config: Configuración de campos PII del YAML
        seed: Semilla para Faker (para reproducibilidad)

    Returns:
        DataFrame anonimizado
    """
    fake = Faker()
    Faker.seed(seed)

    # Crear una copia del DataFrame
    df_anon = df.copy()

    # Diccionario para mantener consistencia en nombres de co-speakers
    # Si una persona es co-speaker en múltiples sesiones, debe tener el mismo nombre falso
    name_mapping = {}
    email_mapping = {}

    # Anonimizar nombres
    for field in pii_config.get("names", []):
        if field in df_anon.columns:
            print(f"   - Anonimizando nombres en: {field}")

            def get_fake_name(original_name):
                if pd.isna(original_name) or original_name == "":
                    return ""
                # Mantener consistencia: mismo nombre original = mismo nombre falso
                if original_name not in name_mapping:
                    name_mapping[original_name] = fake.name()
                return name_mapping[original_name]

            df_anon[field] = df_anon[field].apply(get_fake_name)

    # Anonimizar emails
    for field in pii_config.get("emails", []):
        if field in df_anon.columns:
            print(f"   - Anonimizando emails en: {field}")

            def get_fake_email(original_email):
                if pd.isna(original_email) or original_email == "":
                    return ""
                # Mantener consistencia
                if original_email not in email_mapping:
                    email_mapping[original_email] = fake.email()
                return email_mapping[original_email]

            df_anon[field] = df_anon[field].apply(get_fake_email)

    # Anonimizar URLs (LinkedIn)
    for field in pii_config.get("urls", []):
        if field in df_anon.columns:
            print(f"   - Anonimizando URLs en: {field}")

            def get_fake_url(original_url):
                if pd.isna(original_url) or original_url == "":
                    return ""
                # Generar URL de LinkedIn falsa
                username = fake.user_name()
                return f"https://www.linkedin.com/in/{username}/"

            df_anon[field] = df_anon[field].apply(get_fake_url)

    return df_anon


def main():
    # Parsear argumentos de línea de comandos
    parser = argparse.ArgumentParser(
        description="Convierte sessions.xlsx a CSV para importar en Salesforce"
    )
    parser.add_argument(
        "campaign_id",
        help="ID de la campaña (Campaign) de Salesforce (ej: 701XXXXXXXXXXXXXXX)",
    )
    parser.add_argument(
        "--config",
        default="session-mapping.yml",
        help="Archivo de configuración YAML (default: session-mapping.yml)",
    )
    parser.add_argument(
        "--input",
        default="sessions.xlsx",
        help="Archivo Excel de entrada (default: sessions.xlsx)",
    )
    parser.add_argument(
        "--output",
        default="sessions_import.csv",
        help="Archivo CSV de salida (default: sessions_import.csv)",
    )
    parser.add_argument(
        "--anon",
        action="store_true",
        help="Anonimizar datos PII (nombres, emails, URLs de LinkedIn)",
    )

    args = parser.parse_args()
    campaign_id = args.campaign_id

    # Validar formato básico del Campaign ID (debe empezar con 701 y tener 15 o 18 caracteres)
    if not campaign_id.startswith("701") or len(campaign_id) not in [15, 18]:
        print(f"ERROR: El Campaign ID '{campaign_id}' no parece válido.")
        print("Debe empezar con '701' y tener 15 o 18 caracteres.")
        sys.exit(1)

    print("=" * 80)
    print("CONVERSIÓN DE SESSIONS.XLSX A CSV PARA SALESFORCE")
    print("=" * 80)
    print(f"\nCampaign ID: {campaign_id}")
    if args.anon:
        print("Modo: ANONIMIZACIÓN ACTIVADA (datos PII serán reemplazados)")

    # Cargar configuración
    print("\n[1/6] Cargando configuración...")
    config = load_config(args.config)
    mapping = config.get("mapping", {})
    transformations = config.get("transformations", {})
    defaults = config.get("defaults", {})
    encoding_config = config.get("encoding", {})
    input_encoding = encoding_config.get("input", "utf-8")
    output_encoding = encoding_config.get("output", "utf-8")

    print(f"   - Campos mapeados: {len(mapping)}")
    print(f"   - Transformaciones: {len(transformations)}")
    print(f"   - Valores por defecto: {len(defaults)}")

    # Leer Excel
    print(f"\n[2/6] Leyendo archivo Excel (encoding: {input_encoding})...")
    try:
        df = pd.read_excel(args.input)
        print(f"   - Total de filas leídas: {len(df)}")
        print(f"   - Total de columnas: {len(df.columns)}")
    except Exception as e:
        print(f"ERROR al leer el archivo Excel: {e}")
        sys.exit(1)

    # Crear DataFrame para Salesforce
    print("\n[3/6] Creando DataFrame con campos API de Salesforce...")
    sf_data = {}

    # Mapear columnas
    for excel_col, sf_field in mapping.items():
        if excel_col in df.columns:
            print(f"   - Mapeando: '{excel_col}' -> '{sf_field}'")

            # Aplicar transformaciones si existen
            if sf_field in transformations:
                sf_data[sf_field] = df[excel_col].apply(
                    lambda x: transform_value(x, transformations[sf_field])
                )
            else:
                sf_data[sf_field] = df[excel_col]
        else:
            print(f"   - ADVERTENCIA: Columna '{excel_col}' no encontrada en Excel")

    # Crear DataFrame
    sf_df = pd.DataFrame(sf_data)

    # Agregar valores por defecto
    print("\n[4/6] Agregando valores por defecto...")
    for field, value in defaults.items():
        print(f"   - {field} = '{value}'")
        sf_df[field] = value

    # Agregar Campaign ID (campo obligatorio)
    print("\n[5/6] Agregando Campaign ID...")
    print(f"   - Campaign__c = '{campaign_id}'")
    sf_df["Campaign__c"] = campaign_id

    # Anonimizar datos PII si se solicitó
    if args.anon:
        print("\n[6/7] Anonimizando datos PII...")
        pii_config = config.get("pii_fields", {})
        if pii_config:
            sf_df = anonymize_data(sf_df, pii_config)
            print("   ✓ Datos PII anonimizados correctamente")
        else:
            print("   - ADVERTENCIA: No se encontró configuración PII en el YAML")

    # Limpiar valores
    step_num = "[7/7]" if args.anon else "[6/6]"
    print(f"\n{step_num} Limpiando y normalizando valores...")
    for col in sf_df.columns:
        sf_df[col] = sf_df[col].apply(clean_value)

    # Guardar CSV
    output_file = args.output
    print(f"\nGuardando archivo CSV: {output_file}")
    print(f"   - Encoding: {output_encoding}")

    try:
        sf_df.to_csv(
            output_file,
            index=False,
            encoding=output_encoding,
            # Usar quoting para asegurar que los campos con comas estén bien escapados
            quoting=1,  # csv.QUOTE_ALL
        )
        print(f"   ✓ Archivo creado exitosamente")
        print(f"   - Total de registros: {len(sf_df)}")
        print(f"   - Total de campos: {len(sf_df.columns)}")
    except Exception as e:
        print(f"ERROR al guardar el archivo CSV: {e}")
        sys.exit(1)

    # Mostrar resumen de campos
    print("\n" + "=" * 80)
    print("RESUMEN DE CAMPOS EN EL CSV")
    print("=" * 80)
    for i, col in enumerate(sf_df.columns, 1):
        non_empty = (sf_df[col] != "").sum()
        print(f"{i:2d}. {col:40s} - {non_empty}/{len(sf_df)} valores no vacíos")

    # Mostrar muestra de datos
    print("\n" + "=" * 80)
    print("MUESTRA DE DATOS (primeras 2 filas)")
    print("=" * 80)
    print(sf_df.head(2).to_string())

    print("\n" + "=" * 80)
    print("✓ PROCESO COMPLETADO EXITOSAMENTE")
    print("=" * 80)
    print(f"\nArchivo generado: {output_file}")
    print(
        "Puedes importar este archivo en Salesforce usando Data Loader o Data Import Wizard"
    )


if __name__ == "__main__":
    main()
