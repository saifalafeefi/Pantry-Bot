from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3
from datetime import datetime
import hashlib
import secrets

app = Flask(__name__)
CORS(app)

# Performance optimizations
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0
app.config['JSON_SORT_KEYS'] = False

DB_PATH = 'pantrybot.db'

def hash_password(password):
    """Hash a password for storing."""
    salt = secrets.token_hex(16)
    # Use 100k iterations for better security
    pwdhash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
    return f"{salt}${pwdhash.hex()}"

def verify_password(stored_password, provided_password):
    """Verify a stored password against one provided by user"""
    print(f"DEBUG: stored_password = '{stored_password}'")
    salt, key = stored_password.split('$')
    # Match the 100k iterations
    pwdhash = hashlib.pbkdf2_hmac('sha256', provided_password.encode(), salt.encode(), 100000)
    return pwdhash.hex() == key

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute('PRAGMA journal_mode=WAL')
    conn.execute('PRAGMA synchronous=NORMAL')
    
    # Create users table
    conn.execute('''
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        is_admin BOOLEAN DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    ''')
    
    # Create grocery_items table
    conn.execute('''
    CREATE TABLE IF NOT EXISTS grocery_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity INTEGER DEFAULT 1,
        category TEXT DEFAULT 'Vegetables',
        checked INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        user_id INTEGER,
        priority INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id)
    )
    ''')
    
    # Create items table (pantry items)
    conn.execute('''
    CREATE TABLE IF NOT EXISTS items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        user_id INTEGER,
        FOREIGN KEY (user_id) REFERENCES users (id)
    )
    ''')
    
    # Add user_id column to existing tables if it doesn't exist
    try:
        conn.execute('ALTER TABLE items ADD COLUMN user_id INTEGER')
    except sqlite3.OperationalError:
        pass  # Column already exists
    
    # Add item_history table
    conn.execute('''
    CREATE TABLE IF NOT EXISTS item_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        frequency INTEGER DEFAULT 1,
        UNIQUE(name, category)
    )
    ''')
    
    # Insert default admin user if not exists
    cursor = conn.cursor()
    cursor.execute('SELECT id FROM users WHERE username = ?', ('admin',))
    if not cursor.fetchone():
        cursor.execute(
            'INSERT INTO users (username, password_hash, is_admin) VALUES (?, ?, 1)',
            ('admin', hash_password('TheReal360'))
        )
        cursor.execute(
            'INSERT INTO users (username, password_hash, is_admin) VALUES (?, ?, 0)',
            ('whitehouse', hash_password('Adnoc2003'))
        )
        conn.commit()
    
    return conn

# User management endpoints
@app.route('/auth/login', methods=['POST'])
def login():
    try:
        data = request.json
        if not data or not data.get('username') or not data.get('password'):
            return jsonify({'success': False, 'message': 'Missing credentials'}), 400
            
        conn = get_db()
        cursor = conn.cursor()
        
        # Optimized query - only get what we need
        cursor.execute('SELECT id, username, password_hash, is_admin FROM users WHERE username = ? LIMIT 1', 
                      (data['username'],))
        user = cursor.fetchone()
        conn.close()
        
        if user and verify_password(user['password_hash'], data['password']):
            return jsonify({
                'success': True,
                'user_id': user['id'],
                'username': user['username'],
                'is_admin': bool(user['is_admin'])
            })
        
        return jsonify({'success': False, 'message': 'Invalid credentials'}), 401
        
    except Exception as e:
        print(f"Login error: {e}")
        return jsonify({'success': False, 'message': 'Server error'}), 500

@app.route('/users', methods=['GET'])
def get_users():
    conn = get_db()
    users = conn.execute('SELECT id, username, is_admin, created_at FROM users').fetchall()
    conn.close()
    return jsonify([dict(user) for user in users])

@app.route('/users', methods=['POST'])
def create_user():
    data = request.json
    if not data.get('username') or not data.get('password'):
        return jsonify({'success': False, 'message': 'Missing required fields'}), 400
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            'INSERT INTO users (username, password_hash, is_admin) VALUES (?, ?, ?)',
            (data['username'], hash_password(data['password']), data.get('is_admin', 0))
        )
        conn.commit()
        new_id = cursor.lastrowid
        conn.close()
        return jsonify({'success': True, 'id': new_id})
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({'success': False, 'message': 'Username already exists'}), 409

# Update existing endpoints to be user-specific
@app.route('/grocery/items', methods=['GET'])
def get_items():
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({'error': 'user_id is required'}), 400
        
    conn = get_db()
    items = conn.execute(
        'SELECT * FROM grocery_items WHERE user_id = ? ORDER BY created_at DESC', 
        (user_id,)
    ).fetchall()
    conn.close()
    return jsonify([dict(item) for item in items])

@app.route('/grocery/items', methods=['POST'])
def add_item():
    data = request.json
    print(f"\nReceived add item request: {data}")  # Debug log
    
    if not data.get('user_id'):
        print("Error: No user_id provided")  # Debug log
        return jsonify({'error': 'user_id is required'}), 400
        
    name = data.get('name')
    quantity = data.get('quantity', 1)
    category = data.get('category', '')
    user_id = data.get('user_id')
    
    if not name:
        print("Error: No name provided")  # Debug log
        return jsonify({'error': 'name is required'}), 400

    print(f"Adding item: {name} (qty: {quantity}) for user: {user_id}")  # Debug log

    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # First update or insert into item_history
        cursor.execute('''
            INSERT INTO item_history (name, category, user_id, last_used, frequency)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP, 1)
            ON CONFLICT(name, category, user_id) 
            DO UPDATE SET
                last_used = CURRENT_TIMESTAMP,
                frequency = frequency + 1
            WHERE user_id = ?
        ''', (name, category, user_id, user_id))
        
        # Then insert the new grocery item
        cursor.execute('''
            INSERT INTO grocery_items 
            (name, quantity, category, user_id, checked, created_at) 
            VALUES (?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
        ''', (name, quantity, category, user_id))
        
        new_id = cursor.lastrowid
        
        # Verify the item was added
        cursor.execute('SELECT * FROM grocery_items WHERE id = ?', (new_id,))
        new_item = cursor.fetchone()
        print(f"Added item with ID {new_id}: {dict(new_item)}")  # Debug log
        
        conn.commit()
        
        response_data = {
            'success': True,
            'id': new_id,
            'item': dict(new_item)
        }
        print(f"Sending response: {response_data}")  # Debug log
        return jsonify(response_data)
        
    except sqlite3.Error as e:
        conn.rollback()
        print(f"Database error: {e}")  # Debug log
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

@app.route('/grocery/items/<int:item_id>', methods=['PUT'])
def update_item(item_id):
    data = request.json
    conn = get_db()
    conn.execute(
        'UPDATE grocery_items SET name = ?, quantity = ?, category = ?, checked = ? WHERE id = ?',
        (
            data['name'],
            data.get('quantity', 1),
            data.get('category', 'Vegetables'),
            data.get('checked', 0),
            item_id
        )
    )
    conn.commit()
    conn.close()
    return jsonify({'success': True})

@app.route('/grocery/items/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    conn = get_db()
    conn.execute('DELETE FROM grocery_items WHERE id = ?', (item_id,))
    conn.commit()
    conn.close()
    return jsonify({'success': True})

@app.route('/grocery/suggestions', methods=['GET'])
def get_suggestions():
    query = request.args.get('query', '').lower()
    user_id = request.args.get('user_id')
    is_admin = request.args.get('admin', 'false').lower() == 'true'
    
    if not user_id and not is_admin:
        return jsonify({'error': 'user_id is required'}), 400
        
    conn = get_db()
    if is_admin:
        suggestions = conn.execute('''
            SELECT DISTINCT name, category, MAX(frequency) as frequency 
            FROM item_history 
            WHERE LOWER(name) LIKE ? 
            GROUP BY name, category
            ORDER BY frequency DESC, last_used DESC 
            LIMIT 1000
        ''', (f'%{query}%',)).fetchall()
    else:
        suggestions = conn.execute('''
            SELECT name, category, frequency 
            FROM item_history 
            WHERE LOWER(name) LIKE ? AND user_id = ?
            ORDER BY frequency DESC, last_used DESC 
            LIMIT 5
        ''', (f'%{query}%', user_id)).fetchall()
    
    conn.close()
    return jsonify([dict(item) for item in suggestions])

@app.route('/users/migrate', methods=['POST'])
def migrate_user_data():
    data = request.json
    source_user_id = data.get('source_user_id')
    target_user_id = data.get('target_user_id')
    
    if not source_user_id or not target_user_id:
        return jsonify({'error': 'Both source and target user IDs are required'}), 400
        
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # Copy grocery items
        cursor.execute('''
            INSERT INTO grocery_items (user_id, name, quantity, category, checked, created_at)
            SELECT ?, name, quantity, category, checked, created_at
            FROM grocery_items WHERE user_id = ?
        ''', (target_user_id, source_user_id))
        
        # Copy item history
        cursor.execute('''
            INSERT INTO item_history (user_id, name, category, last_used, frequency)
            SELECT ?, name, category, last_used, frequency
            FROM item_history WHERE user_id = ?
        ''', (target_user_id, source_user_id))
        
        conn.commit()
        return jsonify({'success': True})
    except Exception as e:
        conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

@app.route('/pantry/items', methods=['GET'])
def get_pantry_items():
    user_id = request.args.get('user_id')
    sort_by = request.args.get('sort', 'expiry_date')
    
    if not user_id:
        return jsonify({'error': 'user_id is required'}), 400
    
    conn = get_db()
    
    # Validate sort parameter
    valid_sorts = ['name', 'type', 'expiry_date', 'entry_date', 'quantity']
    if sort_by not in valid_sorts:
        sort_by = 'expiry_date'
    
    items = conn.execute(f'''
        SELECT id, name, type, quantity, entry_date, expiry_date
        FROM items 
        WHERE user_id = ?
        ORDER BY {sort_by} ASC
    ''', (user_id,)).fetchall()
    
    conn.close()
    return jsonify([dict(item) for item in items])

@app.route('/pantry/items', methods=['POST'])
def add_pantry_item():
    data = request.get_json()
    
    required_fields = ['name', 'type', 'quantity', 'expiry_date', 'user_id']
    if not all(field in data for field in required_fields):
        return jsonify({'error': 'Missing required fields'}), 400
    
    conn = get_db()
    
    from datetime import datetime
    entry_date = datetime.now().strftime('%Y-%m-%d')
    
    cursor = conn.execute('''
        INSERT INTO items (name, type, quantity, entry_date, expiry_date, user_id)
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (data['name'], data['type'], data['quantity'], entry_date, data['expiry_date'], data['user_id']))
    
    conn.commit()
    item_id = cursor.lastrowid
    conn.close()
    
    return jsonify({'id': item_id, 'message': 'Item added successfully'}), 201

@app.route('/pantry/items/<int:item_id>', methods=['PUT'])
def update_pantry_item(item_id):
    data = request.get_json()
    
    required_fields = ['name', 'type', 'quantity', 'expiry_date']
    if not all(field in data for field in required_fields):
        return jsonify({'error': 'Missing required fields'}), 400
    
    conn = get_db()
    
    conn.execute('''
        UPDATE items 
        SET name = ?, type = ?, quantity = ?, expiry_date = ?
        WHERE id = ?
    ''', (data['name'], data['type'], data['quantity'], data['expiry_date'], item_id))
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Item updated successfully'})

@app.route('/pantry/items/<int:item_id>', methods=['DELETE'])
def delete_pantry_item(item_id):
    conn = get_db()
    
    conn.execute('DELETE FROM items WHERE id = ?', (item_id,))
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Item deleted successfully'})

@app.route('/pantry/expiring', methods=['GET'])
def get_expiring_pantry_items():
    user_id = request.args.get('user_id')
    days_ahead = request.args.get('days', 3, type=int)
    
    if not user_id:
        return jsonify({'error': 'user_id is required'}), 400
    
    conn = get_db()
    
    # Get items expiring within the specified days
    expiring_items = conn.execute('''
        SELECT name, type, expiry_date,
               CAST((julianday(expiry_date) - julianday('now')) AS INTEGER) as days_until_expiry
        FROM items 
        WHERE user_id = ? 
        AND julianday(expiry_date) - julianday('now') BETWEEN -1 AND ?
        ORDER BY expiry_date ASC
        LIMIT 10
    ''', (user_id, days_ahead)).fetchall()
    
    conn.close()
    return jsonify([dict(item) for item in expiring_items])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000) 