# ***** FLASK, RECEPTOR DE CONSULTAS Y CONVERTIDOR A JSON *****
from flask import Flask, request, jsonify
# ***** CABECERAS HTTPS *****
from flask_cors import CORS
# ***** ENCRIPTADOR *****
from flask_bcrypt import Bcrypt
# ***** SQLITE *****
import sqlite3
# ***** UTILIDADES DE FECHA *****
from datetime import datetime
# ***** SISTEMA OPERATIVO *****
import os

# ***** NOMBRE DE LA APP FLASK *****
app = Flask(__name__)
# ***** INCLUIR CABECERAS *****
CORS(app)
# ***** ENCRIPTAR *****
bcrypt = Bcrypt(app)

# ***** DEFINIR RUTA DE LA BASE DE DATOS *****
DB_PATH = os.path.join(os.path.dirname(__file__), 'data', 'users.db')

# ***** CREAR CONEXIÓN CON LA BD *****
def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

# ***** RECIBIR LOS DATOS DESDE LOGIN CON POST *****
@app.route('/auth-api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    # ***** OBTENER IP DEL CLIENTE *****
    client_ip = request.remote_addr

    # ***** MENSAJE DE ERROR SI NO SE PROPORCIONÓ USUARIO O CLAVE *****
    if not username or not password:
        return jsonify({'success': False, 'message': 'Faltan datos'}), 400

    # ***** OBTENER CONEXIÓN A LA BD *****
    conn = get_db_connection()

    # ***** CONSULTAR USUARIO INGRESADO EN LA BD *****
    user = conn.execute('SELECT * FROM users WHERE username = ? AND is_active = 1', (username,)).fetchone()

    # ***** SI EL USUARIO Y LA CONTRASEÑA SON CORRECTOS *****
    if user and bcrypt.check_password_hash(user['password_hash'], password):
        # ***** GUARDAR EN LA TABLA DE AUDITORÍA COMO ACCESO EXITOSO *****
        conn.execute(
            'INSERT INTO audit_logs (user_id, action, details, ip_address, timestamp) VALUES (?, ?, ?, ?, ?)',
            (user['id'], 'LOGIN_SUCCESS', f"Rol: {user['role']}", client_ip, datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
        )
        conn.commit()
        conn.close()
        return jsonify({'success': True, 'role': user['role'], 'user_id': user['id'], 'message': 'Login exitoso'}), 200
    else:
        # ***** GUARDAR EN LA TABLA DE AUDITORÍA COMO ACCESO FALLIDO *****
        conn.execute(
            'INSERT INTO audit_logs (user_id, action, details, ip_address, timestamp) VALUES (?, ?, ?, ?, ?)',
            (None, 'LOGIN_FAILED', f"Intento con usuario: {username}", client_ip, datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
        )
        conn.commit()
        conn.close()
        return jsonify({'success': False, 'message': 'Credenciales incorrectas'}), 401

# ***** RUTA PARA OBTENER LAS PREFERENCIAS DE CADA USUARIO SEGÚN SU ID *****
@app.route('/auth-api/preferences/<int:user_id>', methods=['GET'])
def get_preferences(user_id):
    conn = get_db_connection()
    prefs = conn.execute('SELECT pref_key, pref_value FROM user_preferences WHERE user_id = ?', (user_id,)).fetchall()
    conn.close()
    prefs_dict = {row['pref_key']: row['pref_value'] for row in prefs}
    return jsonify({'success': True, 'preferences': prefs_dict}), 200

# ***** RUTA PARA ENVIAR LAS PREFERENCIAS DEL USUARIO ACTIVO EN EL MOMENTO *****
@app.route('/auth-api/preferences', methods=['POST'])
def save_preference():
    data = request.get_json()
    user_id = data.get('user_id')
    pref_key = data.get('key')
    pref_value = data.get('value')
    
    conn = get_db_connection()
    conn.execute(
        '''INSERT INTO user_preferences (user_id, pref_key, pref_value, updated_at) VALUES (?, ?, ?, ?) ON CONFLICT(user_id, pref_key) DO UPDATE SET pref_value=excluded.pref_value, updated_at=excluded.updated_at''',
        (user_id, pref_key, pref_value, datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
    )
    conn.commit()
    conn.close()
    return jsonify({"success": True, "message": "Preferencia guardada"}), 200