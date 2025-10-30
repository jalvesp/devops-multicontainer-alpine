# app/main.py
from datetime import datetime
import os

from flask import Flask, jsonify, request, abort
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text
from dotenv import load_dotenv

# Carrega variáveis do .env se estiver presente (dev)
load_dotenv(override=False)

def build_database_uri() -> str:
    # Se DATABASE_URL vier pronto, usa direto (ex.: postgresql+psycopg2://user:pass@host:5432/db)
    url = os.getenv("DATABASE_URL")
    if url:
        return url

    # Caso contrário, monta a partir das variáveis individuais
    user = os.getenv("APP_DB_USER", "app_user")
    password = os.getenv("APP_DB_PASSWORD", "app_password")
    host = os.getenv("DB_HOST", "db")  # nome do serviço do Postgres no docker-compose
    port = os.getenv("DB_PORT", "5432")
    name = os.getenv("APP_DB_NAME", "app_db")
    return f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{name}"

def create_app() -> Flask:
    app = Flask(__name__)

    # Configurações básicas
    app.config["SQLALCHEMY_DATABASE_URI"] = build_database_uri()
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["JSON_SORT_KEYS"] = False
    app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "change-me")

    db.init_app(app)

    with app.app_context():
        db.create_all()  # cria tabelas se não existirem

    register_routes(app)
    return app

db = SQLAlchemy()

class Item(db.Model):
    __tablename__ = "items"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    description = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(
        db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

def register_routes(app: Flask):
    @app.get("/health")
    def health():
        # Valida conexão ao banco
        try:
            db.session.execute(text("SELECT 1"))
            return jsonify({"status": "ok", "db": "up"}), 200
        except Exception as e:
            return jsonify({"status": "degraded", "db": "down", "error": str(e)}), 503

    @app.get("/items")
    def list_items():
        q = request.args.get("search")
        query = Item.query
        if q:
            like = f"%{q}%"
            query = query.filter(Item.name.ilike(like) | Item.description.ilike(like))
        items = query.order_by(Item.id.desc()).all()
        return jsonify([i.to_dict() for i in items]), 200

    @app.post("/items")
    def create_item():
        data = request.get_json(silent=True) or {}
        name = data.get("name")
        description = data.get("description")

        if not name or not isinstance(name, str):
            abort(400, description="Field 'name' is required and must be a string.")

        item = Item(name=name.strip(), description=(description or "").strip() or None)
        db.session.add(item)
        db.session.commit()
        return jsonify(item.to_dict()), 201

    @app.get("/items/<int:item_id>")
    def get_item(item_id: int):
        item = Item.query.get(item_id)
        if not item:
            abort(404, description="Item not found.")
        return jsonify(item.to_dict()), 200

    @app.put("/items/<int:item_id>")
    def update_item(item_id: int):
        item = Item.query.get(item_id)
        if not item:
            abort(404, description="Item not found.")
        data = request.get_json(silent=True) or {}
        name = data.get("name")
        description = data.get("description")
        if name is not None:
            if not isinstance(name, str) or not name.strip():
                abort(400, description="Field 'name' must be a non-empty string.")
            item.name = name.strip()
        if description is not None:
            item.description = description.strip() or None
        db.session.commit()
        return jsonify(item.to_dict()), 200

    @app.delete("/items/<int:item_id>")
    def delete_item(item_id: int):
        item = Item.query.get(item_id)
        if not item:
            abort(404, description="Item not found.")
        db.session.delete(item)
        db.session.commit()
        return jsonify({"deleted": True, "id": item_id}), 200

# Para rodar localmente (fora do Docker) se quiser:
if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8000")))
