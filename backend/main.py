from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import csv
import io
import os
from typing import List, Dict
from statistics import mean

app = FastAPI()

# Configuration CORS pour autoriser les requêtes depuis votre application Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # À modifier en production pour plus de sécurité
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Variable globale pour stocker les données du CSV
csv_data: List[Dict] = []

def process_csv(file_contents: str):
    """Traite le contenu CSV et stocke les données"""
    global csv_data
    csv_data = []
    
    # Lecture du CSV
    reader = csv.DictReader(io.StringIO(file_contents))
    for row in reader:
        # Convertit les valeurs numériques en float
        processed_row = {}
        for key, value in row.items():
            try:
                processed_row[key] = float(value)
            except (ValueError, TypeError):
                processed_row[key] = value
        csv_data.append(processed_row)
    
    return csv_data

def calculate_stats(data: List[Dict]):
    """Calcule les statistiques sur les données numériques"""
    if not data:
        return {"count": 0, "sum": 0, "avg": 0}
    
    # Récupère toutes les valeurs numériques de toutes les colonnes
    numeric_values = []
    for row in data:
        for value in row.values():
            if isinstance(value, (int, float)):
                numeric_values.append(value)
    
    if not numeric_values:
        return {"count": 0, "sum": 0, "avg": 0}
    
    return {
        "count": len(numeric_values),
        "sum": sum(numeric_values),
        "avg": mean(numeric_values)
    }

@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    """Endpoint pour uploader un fichier CSV"""
    if not file.filename.endswith('.csv'):
        raise HTTPException(status_code=400, detail="Seuls les fichiers CSV sont acceptés")
    
    contents = await file.read()
    try:
        process_csv(contents.decode('utf-8'))
        return {"message": "Fichier CSV traité avec succès"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Erreur de traitement du CSV: {str(e)}")

@app.get("/stats")
async def get_stats():
    """Endpoint pour récupérer les statistiques"""
    stats = calculate_stats(csv_data)
    return stats

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)