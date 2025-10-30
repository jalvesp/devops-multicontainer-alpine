# app/wsgi.py
import os
from main import create_app

# Objeto WSGI que o Gunicorn usará: "wsgi:app"
app = create_app()

if __name__ == "__main__":
    # Execução opcional fora do Docker
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8000")))
