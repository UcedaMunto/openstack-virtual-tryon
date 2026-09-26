#!/bin/bash
# Script para generar diagramas PlantUML

ARCHIVO="${1}"
FORMATO="${2:-svg}"
PLANTUML_JAR="/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/plantuml.jar"

if [ -z "$ARCHIVO" ]; then
    echo "❌ Error: Debes proporcionar un archivo .puml"
    echo ""
    echo "Uso: $0 <archivo.puml> [formato]"
    echo ""
    echo "Formatos disponibles:"
    echo "  svg  - Scalable Vector Graphics (recomendado)"
    echo "  png  - Portable Network Graphics"
    echo "  pdf  - Portable Document Format"
    echo ""
    echo "Ejemplo:"
    echo "  $0 relaciones.puml svg"
    exit 1
fi

if [ ! -f "$ARCHIVO" ]; then
    echo "❌ Error: El archivo '$ARCHIVO' no existe"
    exit 1
fi

if [ ! -f "$PLANTUML_JAR" ]; then
    echo "❌ Error: PlantUML JAR no encontrado en $PLANTUML_JAR"
    exit 1
fi

echo "🔄 Generando diagrama..."
echo "   Archivo: $ARCHIVO"
echo "   Formato: $FORMATO"
echo ""

java -jar "$PLANTUML_JAR" "$ARCHIVO" -t$FORMATO

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Diagrama generado exitosamente"
    echo ""
    echo "Archivos generados:"
    ls -lh *.$FORMATO 2>/dev/null | tail -3 | awk '{print "   ", $9, "(" $5 ")"}'
else
    echo "❌ Error al generar el diagrama"
    exit 1
fi
