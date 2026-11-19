# ***** SQLITE *****
import sqlite3
# ***** SISTEMA OPERATIVO *****
import os
# ***** ENCRIPTADOR *****
from flask_bcrypt import Bcrypt

# ***** INICIAR PROCESO DE ENCRIPTACIÓN *****
bcrypt = Bcrypt()

# ***** DEFINIR RUTA DE LA BASE DE DATOS *****
DB_PATH = os.path.join(os.path.dirname(__file__), 'data', 'users.db')

# ***** CREAR LA CARPETA SI NO EXISTE *****
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

# ***** CONECTAR A LA BASE DE DATOS *****
conn = sqlite3.connect(DB_PATH)
c = conn.cursor()

# ***** CREAR TABLA DE USUARIOS *****
c.execute('''CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                role INTEGER NOT NULL DEFAULT 1,
                is_active INTEGER NOT NULL DEFAULT 1
            )''')

# ***** CREAR TABLA DE AUDITORÍA *****
c.execute('''CREATE TABLE IF NOT EXISTS audit_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                action TEXT NOT NULL,
                details TEXT,
                ip_address TEXT,
                timestamp TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )''')

# ***** CREAR TABLA DE PREFERENCIAS DEL USUARIO *****
c.execute('''CREATE TABLE IF NOT EXISTS user_preferences (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                pref_key TEXT NOT NULL,
                pref_value TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                UNIQUE(user_id, pref_key)
            )''')

# ***** INSERTAR USUARIOS *****
new_users = [
    ("pedroVillalba", "admin1234", 1),
    ("miguelMonterola", "admin5678", 1),
    ("victorSoto", "admin91011", 1),
    ("danielaRangel", "admin121314", 1),
]

# ***** HASHEAR CONTRASEÑAS E INSERTAR *****
for user, pwd, role in new_users:
    hash_pwd = bcrypt.generate_password_hash(pwd).decode('utf-8')
    c.execute("INSERT OR IGNORE INTO users (username, password_hash, role) VALUES (?, ?, ?)", (user, hash_pwd, role))

# ***** REALIZAR CAMBIOS Y CERRAR *****
conn.commit()
conn.close()

# ***** MOSTRAR LOG *****
print("¡Base de datos creada con éxito en 'data/users.db'!")