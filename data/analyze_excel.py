#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script temporal para analizar las columnas del archivo sessions.xlsx
"""
import pandas as pd

# Leer el archivo Excel
file_path = "sessions.xlsx"
df = pd.read_excel(file_path)

print("=" * 80)
print("ANÁLISIS DEL ARCHIVO SESSIONS.XLSX")
print("=" * 80)
print(f"\nTotal de filas: {len(df)}")
print(f"Total de columnas: {len(df.columns)}")
print("\nColumnas encontradas:")
print("-" * 80)
for i, col in enumerate(df.columns, 1):
    print(f"{i:2d}. {col}")

print("\n" + "=" * 80)
print("MUESTRA DE DATOS (primeras 3 filas)")
print("=" * 80)
print(df.head(3).to_string())

print("\n" + "=" * 80)
print("TIPOS DE DATOS")
print("=" * 80)
print(df.dtypes)
