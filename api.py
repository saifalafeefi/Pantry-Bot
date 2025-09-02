from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import sqlite3
from datetime import datetime, timedelta
import hashlib
import secrets
import os
import math

app = Flask(__name__)
CORS(app)

# Performance optimizations
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0
app.config['JSON_SORT_KEYS'] = False

DB_PATH = 'pantrybot.db'

# App version configuration
APP_VERSION = "1.5.0"

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
        metric TEXT DEFAULT NULL,
        amount_per_item TEXT DEFAULT NULL,
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
        metric TEXT DEFAULT NULL,
        amount_per_item TEXT DEFAULT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
    )
    ''')
    
    # Add metric column to existing tables if it doesn't exist
    try:
        conn.execute('ALTER TABLE grocery_items ADD COLUMN metric TEXT DEFAULT NULL')
    except sqlite3.OperationalError:
        pass
    try:
        conn.execute('ALTER TABLE items ADD COLUMN metric TEXT DEFAULT NULL')
    except sqlite3.OperationalError:
        pass
    
    # Add amount_per_item column to existing tables if it doesn't exist
    try:
        conn.execute('ALTER TABLE grocery_items ADD COLUMN amount_per_item TEXT DEFAULT NULL')
    except sqlite3.OperationalError:
        pass
    try:
        conn.execute('ALTER TABLE items ADD COLUMN amount_per_item TEXT DEFAULT NULL')
    except sqlite3.OperationalError:
        pass
    
    # Add item_history table
    conn.execute('''
    CREATE TABLE IF NOT EXISTS item_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        frequency INTEGER DEFAULT 0,
        user_id INTEGER,
        metric TEXT DEFAULT NULL,
        amount_per_item TEXT DEFAULT NULL,
        UNIQUE(name, category, user_id)
    )
    ''')
    
    try:
        conn.execute('ALTER TABLE item_history ADD COLUMN metric TEXT DEFAULT NULL')
    except sqlite3.OperationalError:
        pass
    try:
        conn.execute('ALTER TABLE item_history ADD COLUMN amount_per_item TEXT DEFAULT NULL')
    except sqlite3.OperationalError:
        pass
    
    # Add urgency tracking columns to item_history
    try:
        conn.execute('ALTER TABLE item_history ADD COLUMN days_since_last_use INTEGER DEFAULT 0')
    except sqlite3.OperationalError:
        pass
    try:
        conn.execute('ALTER TABLE item_history ADD COLUMN average_interval REAL DEFAULT 7.0')
    except sqlite3.OperationalError:
        pass
    try:
        conn.execute('ALTER TABLE item_history ADD COLUMN predicted_next_use DATE')
    except sqlite3.OperationalError:
        pass
    
    # Create item_urgency table for frequency tracking and urgency management
    conn.execute('''
    CREATE TABLE IF NOT EXISTS item_urgency (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        category TEXT NOT NULL,
        urgency_level INTEGER DEFAULT 3,
        is_manual_override BOOLEAN DEFAULT 0,
        auto_calculated_urgency INTEGER DEFAULT 3,
        last_purchased_days_ago INTEGER DEFAULT 0,
        average_purchase_interval REAL DEFAULT 7.0,
        notification_enabled BOOLEAN DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, item_name, category)
    )
    ''')
    
    # Create notification_log table
    conn.execute('''
    CREATE TABLE IF NOT EXISTS notification_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        urgency_level INTEGER NOT NULL,
        sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        notification_type TEXT DEFAULT 'reminder'
    )
    ''')
    
    # Create recipes table
    conn.execute('''
    CREATE TABLE IF NOT EXISTS recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        image_path TEXT,
        prep_time INTEGER,
        cook_time INTEGER,
        servings INTEGER,
        date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id)
    )
    ''')
    
    # Create recipe_ingredients table
    conn.execute('''
    CREATE TABLE IF NOT EXISTS recipe_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        ingredient_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
    )
    ''')
    
    # Create recipe_steps table
    conn.execute('''
    CREATE TABLE IF NOT EXISTS recipe_steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        step_number INTEGER NOT NULL,
        instruction TEXT NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
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

@app.route('/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    print(f"Attempting to delete user ID: {user_id}")  # Debug log
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # Check if user exists first
        cursor.execute('SELECT id, username FROM users WHERE id = ?', (user_id,))
        user = cursor.fetchone()
        
        if not user:
            print(f"User ID {user_id} not found in database")  # Debug log
            conn.close()
            return jsonify({'success': False, 'message': 'User not found'}), 404
            
        print(f"Found user: {user['username']} (ID: {user['id']})")  # Debug log
        
        # Delete user's items first (foreign key constraints)
        cursor.execute('DELETE FROM grocery_items WHERE user_id = ?', (user_id,))
        deleted_grocery = cursor.rowcount
        print(f"Deleted {deleted_grocery} grocery items")  # Debug log
        
        cursor.execute('DELETE FROM items WHERE user_id = ?', (user_id,))
        deleted_pantry = cursor.rowcount
        print(f"Deleted {deleted_pantry} pantry items")  # Debug log
        
        cursor.execute('DELETE FROM item_history WHERE user_id = ?', (user_id,))
        deleted_history = cursor.rowcount
        print(f"Deleted {deleted_history} history items")  # Debug log
        
        # Delete the user
        cursor.execute('DELETE FROM users WHERE id = ?', (user_id,))
        deleted_user = cursor.rowcount
        print(f"Deleted user: {deleted_user} row(s)")  # Debug log
            
        conn.commit()
        conn.close()
        print(f"Successfully deleted user {user['username']}")  # Debug log
        return jsonify({'success': True, 'message': 'User deleted successfully'})
        
    except sqlite3.Error as e:
        print(f"Database error during user deletion: {e}")  # Debug log
        conn.rollback()
        conn.close()
        return jsonify({'success': False, 'message': str(e)}), 500

# Update existing endpoints to be user-specific
@app.route('/grocery/items', methods=['GET'])
def get_items():
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({'error': 'user_id is required'}), 400
        
    conn = get_db()
    # Enhanced query to include urgency data from item_history and item_urgency
    items = conn.execute('''
        SELECT 
            g.*,
            h.frequency,
            h.last_used,
            h.days_since_last_use,
            h.average_interval,
            COALESCE(u.urgency_level, 
                CASE 
                    WHEN h.frequency IS NULL THEN 3
                    ELSE CASE 
                        WHEN (julianday('now') - julianday(h.last_used)) / h.average_interval >= 2.0 THEN 5
                        WHEN (julianday('now') - julianday(h.last_used)) / h.average_interval >= 1.5 THEN 4
                        WHEN (julianday('now') - julianday(h.last_used)) / h.average_interval >= 1.0 THEN 3
                        WHEN (julianday('now') - julianday(h.last_used)) / h.average_interval >= 0.7 THEN 2
                        ELSE 1
                    END
                END
            ) as urgency_level,
            u.is_manual_override,
            u.notification_enabled
        FROM grocery_items g
        LEFT JOIN item_history h ON g.user_id = h.user_id AND g.name = h.name AND g.category = h.category
        LEFT JOIN item_urgency u ON g.user_id = u.user_id AND g.name = u.item_name AND g.category = u.category
        WHERE g.user_id = ? 
        ORDER BY 
            COALESCE(u.urgency_level, 
                CASE 
                    WHEN h.frequency IS NULL THEN 3
                    ELSE CASE 
                        WHEN (julianday('now') - julianday(h.last_used)) / h.average_interval >= 2.0 THEN 5
                        WHEN (julianday('now') - julianday(h.last_used)) / h.average_interval >= 1.5 THEN 4
                        WHEN (julianday('now') - julianday(h.last_used)) / h.average_interval >= 1.0 THEN 3
                        WHEN (julianday('now') - julianday(h.last_used)) / h.average_interval >= 0.7 THEN 2
                        ELSE 1
                    END
                END
            ) DESC, g.created_at DESC
    ''', (user_id,)).fetchall()
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
    metric = data.get('metric')
    amount_per_item = data.get('amount_per_item')
    
    if not name:
        print("Error: No name provided")  # Debug log
        return jsonify({'error': 'name is required'}), 400

    print(f"Adding item: {name} (qty: {quantity}) for user: {user_id}")  # Debug log

    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # First update or insert into item_history
        cursor.execute('''
            INSERT INTO item_history (name, category, user_id, last_used, frequency, metric, amount_per_item)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP, 1, ?, ?)
            ON CONFLICT(name, category, user_id) 
            DO UPDATE SET
                last_used = CURRENT_TIMESTAMP,
                frequency = COALESCE(frequency, 0) + 1,
                metric = excluded.metric,
                amount_per_item = excluded.amount_per_item
            WHERE user_id = ?
        ''', (name, category, user_id, metric, amount_per_item, user_id))
        
        # Then insert the new grocery item
        cursor.execute('''
            INSERT INTO grocery_items 
            (name, quantity, category, user_id, checked, created_at, metric, amount_per_item) 
            VALUES (?, ?, ?, ?, 0, CURRENT_TIMESTAMP, ?, ?)
        ''', (name, quantity, category, user_id, metric, amount_per_item))
        
        new_id = cursor.lastrowid
        
        # Calculate and update urgency for this item
        cursor.execute('''
            SELECT frequency, last_used, average_interval
            FROM item_history
            WHERE user_id = ? AND name = ? AND category = ?
        ''', (user_id, name, category))
        
        history = cursor.fetchone()
        if history:
            days_since = 0  # Just added, so 0 days since last use
            auto_urgency = calculate_urgency_score(
                history['frequency'] or 0,
                days_since,
                history['average_interval'] or 7.0
            )
            
            # Update or insert urgency record (only if not manually overridden)
            cursor.execute('''
                INSERT OR REPLACE INTO item_urgency 
                (user_id, item_name, category, urgency_level, is_manual_override, 
                 auto_calculated_urgency, last_purchased_days_ago, updated_at)
                SELECT ?, ?, ?, 
                       CASE WHEN u.is_manual_override = 1 THEN u.urgency_level ELSE ? END,
                       COALESCE(u.is_manual_override, 0),
                       ?, 0, CURRENT_TIMESTAMP
                FROM (SELECT 1) dummy
                LEFT JOIN item_urgency u ON u.user_id = ? AND u.item_name = ? AND u.category = ?
            ''', (user_id, name, category, auto_urgency, auto_urgency, user_id, name, category))
        
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
        'UPDATE grocery_items SET name = ?, quantity = ?, category = ?, checked = ?, metric = ?, amount_per_item = ? WHERE id = ?',
        (
            data['name'],
            data.get('quantity', 1),
            data.get('category', 'Vegetables'),
            data.get('checked', 0),
            data.get('metric'),
            data.get('amount_per_item'),
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
            SELECT name, category, COALESCE(frequency,0) as use_count, metric, amount_per_item, last_used
            FROM item_history 
            WHERE LOWER(name) LIKE ? AND user_id = ?
            ORDER BY use_count DESC, last_used DESC 
            LIMIT 1000
        ''', (f'%{query}%', user_id)).fetchall()
    else:
        suggestions = conn.execute('''
            SELECT name, category, COALESCE(frequency,0) as use_count, metric, amount_per_item
            FROM item_history 
            WHERE LOWER(name) LIKE ? AND user_id = ?
            ORDER BY use_count DESC, last_used DESC 
            LIMIT 5
        ''', (f'%{query}%', user_id)).fetchall()
    
    conn.close()
    return jsonify([dict(item) for item in suggestions])

@app.route('/grocery/suggestions/<suggestion_name>/<suggestion_category>/<int:user_id>', methods=['DELETE'])
def delete_suggestion(suggestion_name, suggestion_category, user_id):
    try:
        conn = get_db()
        cursor = conn.cursor()
        
        # Delete the specific suggestion from item_history
        cursor.execute('''
            DELETE FROM item_history 
            WHERE name = ? AND category = ? AND user_id = ?
        ''', (suggestion_name, suggestion_category, user_id))
        
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({'success': False, 'message': 'Suggestion not found'}), 404
            
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Suggestion deleted successfully'})
        
    except Exception as e:
        print(f"Delete suggestion error: {e}")
        return jsonify({'success': False, 'message': 'Server error'}), 500

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
            INSERT INTO grocery_items (user_id, name, quantity, category, checked, created_at, metric, amount_per_item)
            SELECT ?, name, quantity, category, checked, created_at, metric, amount_per_item
            FROM grocery_items WHERE user_id = ?
        ''', (target_user_id, source_user_id))
        
        # Copy item history
        cursor.execute('''
            INSERT INTO item_history (user_id, name, category, last_used, frequency, metric, amount_per_item)
            SELECT ?, name, category, last_used, frequency, metric, amount_per_item
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
        SELECT id, name, type, quantity, entry_date, expiry_date, metric, amount_per_item
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
    metric = data.get('metric')
    amount_per_item = data.get('amount_per_item')
    
    cursor = conn.execute('''
        INSERT INTO items (name, type, quantity, entry_date, expiry_date, user_id, metric, amount_per_item)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', (data['name'], data['type'], data['quantity'], entry_date, data['expiry_date'], data['user_id'], metric, amount_per_item))
    
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
    
    metric = data.get('metric')
    amount_per_item = data.get('amount_per_item')
    conn.execute('''
        UPDATE items 
        SET name = ?, type = ?, quantity = ?, expiry_date = ?, metric = ?, amount_per_item = ?
        WHERE id = ?
    ''', (data['name'], data['type'], data['quantity'], data['expiry_date'], metric, amount_per_item, item_id))
    
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

@app.route('/version', methods=['GET'])
def get_version():
    return jsonify({'version': APP_VERSION})

@app.route('/api/version', methods=['GET'])
def get_api_version():
    return jsonify({'version': APP_VERSION})

@app.route('/api/apk', methods=['GET'])
def get_apk():
    apk_path = f"/home/smiley/pantrybot/pantrybot_v{APP_VERSION}.apk"
    try:
        return send_file(apk_path, as_attachment=True, download_name=f"pantrybot_v{APP_VERSION}.apk")
    except FileNotFoundError:
        return jsonify({'error': 'APK file not found'}), 404

@app.route('/api/apk/latest', methods=['GET'])
def get_latest_apk():
    """Get the latest APK from releases folder"""
    releases_path = "/home/smiley/pantrybot/releases"
    try:
        # Debug: Check if folder exists
        if not os.path.exists(releases_path):
            return jsonify({'error': f'Releases folder does not exist: {releases_path}'}), 404
        
        # Debug: List all files in releases folder
        all_files = os.listdir(releases_path)
        print(f"DEBUG: All files in {releases_path}: {all_files}")
        
        # Get all APK files in releases folder
        apk_files = [f for f in all_files if f.endswith('.apk')]
        print(f"DEBUG: APK files found: {apk_files}")
        
        if not apk_files:
            return jsonify({
                'error': 'No APK files found', 
                'folder': releases_path,
                'all_files': all_files
            }), 404
        
        # Sort by modification time, get latest
        apk_files.sort(key=lambda x: os.path.getmtime(os.path.join(releases_path, x)), reverse=True)
        latest_apk = apk_files[0]
        
        print(f"DEBUG: Serving latest APK: {latest_apk}")
        
        return send_file(
            os.path.join(releases_path, latest_apk), 
            as_attachment=True, 
            download_name=latest_apk
        )
    except Exception as e:
        print(f"DEBUG: Exception in get_latest_apk: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/apk/latest/info', methods=['GET'])
def get_latest_apk_info():
    """Get info about the latest APK"""
    releases_path = "/home/smiley/pantrybot/releases"
    try:
        apk_files = [f for f in os.listdir(releases_path) if f.endswith('.apk')]
        if not apk_files:
            return jsonify({'error': 'No APK files found'}), 404
        
        apk_files.sort(key=lambda x: os.path.getmtime(os.path.join(releases_path, x)), reverse=True)
        latest_apk = apk_files[0]
        
        # Extract version from filename
        version_info = latest_apk.replace('pantrybot_v', '').replace('.apk', '')
        file_path = os.path.join(releases_path, latest_apk)
        
        return jsonify({
            'filename': latest_apk,
            'version': version_info,
            'upload_date': datetime.fromtimestamp(os.path.getmtime(file_path)).isoformat(),
            'size': os.path.getsize(file_path)
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Recipe management endpoints
@app.route('/recipes', methods=['GET'])
def get_recipes():
    try:
        user_id = request.args.get('user_id')
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute('''
            SELECT id, title, description, image_path, prep_time, cook_time, 
                   servings, date_added
            FROM recipes 
            WHERE user_id = ? 
            ORDER BY date_added DESC
        ''', (user_id,))
        
        recipes = []
        for row in cursor.fetchall():
            recipes.append({
                'id': row['id'],
                'title': row['title'],
                'description': row['description'],
                'image_path': row['image_path'],
                'prep_time': row['prep_time'],
                'cook_time': row['cook_time'],
                'servings': row['servings'],
                'date_added': row['date_added']
            })
        
        conn.close()
        return jsonify(recipes)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/recipes', methods=['POST'])
def create_recipe():
    try:
        data = request.json
        required_fields = ['user_id', 'title']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        # Insert recipe
        cursor.execute('''
            INSERT INTO recipes (user_id, title, description, image_path, 
                               prep_time, cook_time, servings) 
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            data['user_id'],
            data['title'],
            data.get('description', ''),
            data.get('image_path'),
            data.get('prep_time', 0),
            data.get('cook_time', 0),
            data.get('servings', 1)
        ))
        
        recipe_id = cursor.lastrowid
        
        # Insert ingredients
        if 'ingredients' in data:
            for ingredient in data['ingredients']:
                cursor.execute('''
                    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, 
                                                  quantity, unit, notes) 
                    VALUES (?, ?, ?, ?, ?)
                ''', (
                    recipe_id,
                    ingredient['name'],
                    ingredient['quantity'],
                    ingredient['unit'],
                    ingredient.get('notes', '')
                ))
        
        # Insert steps
        if 'steps' in data:
            for i, step in enumerate(data['steps'], 1):
                cursor.execute('''
                    INSERT INTO recipe_steps (recipe_id, step_number, instruction) 
                    VALUES (?, ?, ?)
                ''', (recipe_id, i, step))
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'recipe_id': recipe_id}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/recipes/<int:recipe_id>', methods=['GET'])
def get_recipe_details(recipe_id):
    try:
        user_id = request.args.get('user_id')
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        # Get recipe
        cursor.execute('''
            SELECT id, title, description, image_path, prep_time, cook_time, 
                   servings, date_added
            FROM recipes 
            WHERE id = ? AND user_id = ?
        ''', (recipe_id, user_id))
        
        recipe_row = cursor.fetchone()
        if not recipe_row:
            return jsonify({'error': 'Recipe not found'}), 404
        
        recipe = {
            'id': recipe_row['id'],
            'title': recipe_row['title'],
            'description': recipe_row['description'],
            'image_path': recipe_row['image_path'],
            'prep_time': recipe_row['prep_time'],
            'cook_time': recipe_row['cook_time'],
            'servings': recipe_row['servings'],
            'date_added': recipe_row['date_added']
        }
        
        # Get ingredients
        cursor.execute('''
            SELECT ingredient_name, quantity, unit, notes
            FROM recipe_ingredients 
            WHERE recipe_id = ?
            ORDER BY id
        ''', (recipe_id,))
        
        recipe['ingredients'] = []
        for row in cursor.fetchall():
            recipe['ingredients'].append({
                'name': row['ingredient_name'],
                'quantity': row['quantity'],
                'unit': row['unit'],
                'notes': row['notes']
            })
        
        # Get steps
        cursor.execute('''
            SELECT step_number, instruction
            FROM recipe_steps 
            WHERE recipe_id = ?
            ORDER BY step_number
        ''', (recipe_id,))
        
        recipe['steps'] = []
        for row in cursor.fetchall():
            recipe['steps'].append({
                'number': row['step_number'],
                'instruction': row['instruction']
            })
        
        conn.close()
        return jsonify(recipe)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/recipes/<int:recipe_id>/ingredients/status', methods=['GET'])
def get_recipe_ingredients_status(recipe_id):
    try:
        user_id = request.args.get('user_id')
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        # Get recipe ingredients
        cursor.execute('''
            SELECT ingredient_name, quantity, unit
            FROM recipe_ingredients 
            WHERE recipe_id = ?
        ''', (recipe_id,))
        
        ingredients_status = []
        for row in cursor.fetchall():
            ingredient_name = row['ingredient_name']
            required_quantity = row['quantity']
            unit = row['unit']
            
            # Check pantry for this ingredient
            cursor.execute('''
                SELECT quantity, metric, amount_per_item
                FROM items 
                WHERE user_id = ? AND LOWER(name) LIKE LOWER(?)
            ''', (user_id, f'%{ingredient_name}%'))
            
            pantry_item = cursor.fetchone()
            
            if pantry_item:
                available_quantity = pantry_item['quantity']
                # Simple availability check (could be improved with unit conversion)
                if available_quantity >= required_quantity:
                    status = 'available'
                elif available_quantity > 0:
                    status = 'low_stock'
                else:
                    status = 'unavailable'
            else:
                status = 'unavailable'
            
            ingredients_status.append({
                'name': ingredient_name,
                'required_quantity': required_quantity,
                'unit': unit,
                'status': status,
                'available_quantity': pantry_item['quantity'] if pantry_item else 0
            })
        
        conn.close()
        return jsonify(ingredients_status)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/recipes/<int:recipe_id>', methods=['PUT'])
def update_recipe(recipe_id):
    try:
        data = request.json
        required_fields = ['user_id', 'title']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        # Verify recipe ownership
        cursor.execute('SELECT id FROM recipes WHERE id = ? AND user_id = ?', (recipe_id, data['user_id']))
        if not cursor.fetchone():
            return jsonify({'error': 'Recipe not found or access denied'}), 404
        
        # Update recipe
        cursor.execute('''
            UPDATE recipes SET title = ?, description = ?, prep_time = ?, 
                             cook_time = ?, servings = ?
            WHERE id = ? AND user_id = ?
        ''', (
            data['title'],
            data.get('description', ''),
            data.get('prep_time', 0),
            data.get('cook_time', 0),
            data.get('servings', 1),
            recipe_id,
            data['user_id']
        ))
        
        # Delete existing ingredients and steps
        cursor.execute('DELETE FROM recipe_ingredients WHERE recipe_id = ?', (recipe_id,))
        cursor.execute('DELETE FROM recipe_steps WHERE recipe_id = ?', (recipe_id,))
        
        # Insert updated ingredients
        if 'ingredients' in data:
            for ingredient in data['ingredients']:
                cursor.execute('''
                    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, 
                                                  quantity, unit, notes) 
                    VALUES (?, ?, ?, ?, ?)
                ''', (
                    recipe_id,
                    ingredient['name'],
                    ingredient['quantity'],
                    ingredient['unit'],
                    ingredient.get('notes', '')
                ))
        
        # Insert updated steps
        if 'steps' in data:
            for i, step in enumerate(data['steps'], 1):
                cursor.execute('''
                    INSERT INTO recipe_steps (recipe_id, step_number, instruction) 
                    VALUES (?, ?, ?)
                ''', (recipe_id, i, step))
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/recipes/<int:recipe_id>', methods=['DELETE'])
def delete_recipe(recipe_id):
    try:
        user_id = request.args.get('user_id')
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        # Verify recipe ownership
        cursor.execute('SELECT id FROM recipes WHERE id = ? AND user_id = ?', (recipe_id, user_id))
        if not cursor.fetchone():
            return jsonify({'error': 'Recipe not found or access denied'}), 404
        
        # Delete recipe (ingredients and steps will be deleted due to CASCADE)
        cursor.execute('DELETE FROM recipes WHERE id = ? AND user_id = ?', (recipe_id, user_id))
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/ingredients/suggestions', methods=['GET'])
def get_ingredient_suggestions():
    try:
        user_id = request.args.get('user_id')
        query = request.args.get('query', '').lower()
        
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        suggestions = []
        
        if query:
            # Get suggestions from item_history (same as grocery suggestions)
            cursor.execute('''
                SELECT DISTINCT name, category, metric, amount_per_item, frequency 
                FROM item_history 
                WHERE user_id = ? AND LOWER(name) LIKE LOWER(?) 
                ORDER BY frequency DESC, name ASC 
                LIMIT 10
            ''', (user_id, f'%{query}%'))
            
            for row in cursor.fetchall():
                suggestions.append({
                    'name': row['name'],
                    'category': row['category'],
                    'metric': row['metric'] or 'Piece',
                    'amount_per_item': row['amount_per_item'] or '',
                    'frequency': row['frequency']
                })
        
        conn.close()
        return jsonify(suggestions)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/ingredients/add-to-history', methods=['POST'])
def add_ingredient_to_history():
    try:
        data = request.json
        required_fields = ['user_id', 'name', 'category']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        # Add to item_history for future autocomplete
        cursor.execute('''
            INSERT OR REPLACE INTO item_history 
            (name, category, user_id, metric, amount_per_item, frequency, last_used) 
            VALUES (?, ?, ?, ?, ?, 
                    COALESCE((SELECT frequency + 1 FROM item_history WHERE name = ? AND category = ? AND user_id = ?), 1),
                    CURRENT_TIMESTAMP)
        ''', (
            data['name'],
            data['category'],
            data['user_id'],
            data.get('metric', 'Piece'),
            data.get('amount_per_item', ''),
            data['name'],
            data['category'], 
            data['user_id']
        ))
        
        conn.commit()
        conn.close()
        
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ===== URGENCY TRACKING & FREQUENCY ANALYSIS ENDPOINTS =====

def calculate_urgency_score(frequency, days_since_last, average_interval, user_override=None):
    """Calculate urgency score from 1-5 based on frequency patterns"""
    if user_override:
        return user_override
    
    # Base urgency calculation
    if frequency == 0:
        return 2  # Medium - no history
    
    # Calculate expected vs actual time since last purchase
    overdue_ratio = days_since_last / max(average_interval, 1.0)
    
    if overdue_ratio >= 2.0:
        return 5  # Emergency - way overdue
    elif overdue_ratio >= 1.5:
        return 4  # Critical - overdue
    elif overdue_ratio >= 1.0:
        return 3  # High - due
    elif overdue_ratio >= 0.7:
        return 2  # Medium - approaching
    else:
        return 1  # Low - still fresh

@app.route('/urgency/items', methods=['GET'])
def get_urgency_items():
    """Get all items with urgency levels for a user"""
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({'error': 'user_id is required'}), 400
    
    try:
        conn = get_db()
        
        # Get items from grocery history with urgency data
        items = conn.execute('''
            SELECT 
                h.name,
                h.category,
                h.frequency,
                h.last_used,
                h.days_since_last_use,
                h.average_interval,
                u.urgency_level,
                u.is_manual_override,
                u.auto_calculated_urgency,
                u.last_purchased_days_ago,
                u.notification_enabled,
                u.updated_at as urgency_updated
            FROM item_history h
            LEFT JOIN item_urgency u ON h.user_id = u.user_id AND h.name = u.item_name AND h.category = u.category
            WHERE h.user_id = ?
            ORDER BY COALESCE(u.urgency_level, 3) DESC, h.frequency DESC
        ''', (user_id,)).fetchall()
        
        result = []
        for item in items:
            # Calculate current urgency if not manually set
            days_since = (datetime.now() - datetime.fromisoformat(item['last_used'].replace('Z', '+00:00'))).days if item['last_used'] else 999
            auto_urgency = calculate_urgency_score(
                item['frequency'] or 0,
                days_since,
                item['average_interval'] or 7.0
            )
            
            result.append({
                'name': item['name'],
                'category': item['category'],
                'frequency': item['frequency'] or 0,
                'days_since_last': days_since,
                'average_interval': item['average_interval'] or 7.0,
                'urgency_level': item['urgency_level'] or auto_urgency,
                'auto_calculated_urgency': auto_urgency,
                'is_manual_override': bool(item['is_manual_override']),
                'notification_enabled': bool(item['notification_enabled']) if item['notification_enabled'] is not None else True,
                'last_used': item['last_used'],
                'urgency_updated': item['urgency_updated']
            })
        
        conn.close()
        return jsonify(result)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/urgency/items/<item_name>/<category>/<int:user_id>', methods=['PUT'])
def update_urgency_manual(item_name, category, user_id):
    """Manually update urgency level for an item"""
    try:
        data = request.json
        urgency_level = data.get('urgency_level', 3)
        notification_enabled = data.get('notification_enabled', True)
        
        if not (1 <= urgency_level <= 5):
            return jsonify({'error': 'urgency_level must be between 1 and 5'}), 400
        
        conn = get_db()
        
        # Calculate auto urgency for comparison
        item_history = conn.execute('''
            SELECT frequency, last_used, average_interval
            FROM item_history 
            WHERE user_id = ? AND name = ? AND category = ?
        ''', (user_id, item_name, category)).fetchone()
        
        auto_urgency = 3  # default
        if item_history:
            days_since = (datetime.now() - datetime.fromisoformat(item_history['last_used'].replace('Z', '+00:00'))).days if item_history['last_used'] else 999
            auto_urgency = calculate_urgency_score(
                item_history['frequency'] or 0,
                days_since,
                item_history['average_interval'] or 7.0
            )
        
        # Insert or update urgency record
        conn.execute('''
            INSERT OR REPLACE INTO item_urgency 
            (user_id, item_name, category, urgency_level, is_manual_override, 
             auto_calculated_urgency, notification_enabled, updated_at)
            VALUES (?, ?, ?, ?, 1, ?, ?, CURRENT_TIMESTAMP)
        ''', (user_id, item_name, category, urgency_level, auto_urgency, notification_enabled))
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'urgency_level': urgency_level,
            'auto_calculated_urgency': auto_urgency,
            'is_manual_override': True
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/urgency/calculate/<int:user_id>', methods=['POST'])
def recalculate_urgencies(user_id):
    """Recalculate all auto urgencies for a user"""
    try:
        conn = get_db()
        
        # Get all items from history
        items = conn.execute('''
            SELECT name, category, frequency, last_used, average_interval
            FROM item_history 
            WHERE user_id = ?
        ''', (user_id,)).fetchall()
        
        updated_count = 0
        for item in items:
            days_since = (datetime.now() - datetime.fromisoformat(item['last_used'].replace('Z', '+00:00'))).days if item['last_used'] else 999
            auto_urgency = calculate_urgency_score(
                item['frequency'] or 0,
                days_since,
                item['average_interval'] or 7.0
            )
            
            # Update days since last use in history
            conn.execute('''
                UPDATE item_history 
                SET days_since_last_use = ?
                WHERE user_id = ? AND name = ? AND category = ?
            ''', (days_since, user_id, item['name'], item['category']))
            
            # Update or insert urgency (only if not manually overridden)
            conn.execute('''
                INSERT OR REPLACE INTO item_urgency 
                (user_id, item_name, category, urgency_level, is_manual_override, 
                 auto_calculated_urgency, last_purchased_days_ago, updated_at)
                SELECT ?, ?, ?, 
                       CASE WHEN u.is_manual_override = 1 THEN u.urgency_level ELSE ? END,
                       COALESCE(u.is_manual_override, 0),
                       ?, ?, CURRENT_TIMESTAMP
                FROM (SELECT 1) dummy
                LEFT JOIN item_urgency u ON u.user_id = ? AND u.item_name = ? AND u.category = ?
            ''', (user_id, item['name'], item['category'], auto_urgency, auto_urgency, days_since, user_id, item['name'], item['category']))
            
            updated_count += 1
        
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'updated_items': updated_count,
            'message': f'Recalculated urgency for {updated_count} items'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/urgency/analytics/<int:user_id>', methods=['GET'])
def get_urgency_analytics(user_id):
    """Get frequency analytics and trends for a user"""
    try:
        conn = get_db()
        
        # Get urgency distribution
        urgency_distribution = conn.execute('''
            SELECT 
                COALESCE(u.urgency_level, 3) as urgency,
                COUNT(*) as count
            FROM item_history h
            LEFT JOIN item_urgency u ON h.user_id = u.user_id AND h.name = u.item_name AND h.category = u.category
            WHERE h.user_id = ?
            GROUP BY COALESCE(u.urgency_level, 3)
            ORDER BY urgency
        ''', (user_id,)).fetchall()
        
        # Get top frequent items
        top_frequent = conn.execute('''
            SELECT name, category, frequency, average_interval, last_used
            FROM item_history 
            WHERE user_id = ?
            ORDER BY frequency DESC
            LIMIT 10
        ''', (user_id,)).fetchall()
        
        # Get overdue items
        overdue_items = conn.execute('''
            SELECT h.name, h.category, h.frequency, h.days_since_last_use, h.average_interval,
                   COALESCE(u.urgency_level, 3) as urgency_level
            FROM item_history h
            LEFT JOIN item_urgency u ON h.user_id = u.user_id AND h.name = u.item_name AND h.category = u.category
            WHERE h.user_id = ? AND h.days_since_last_use > h.average_interval
            ORDER BY (h.days_since_last_use / h.average_interval) DESC
            LIMIT 20
        ''', (user_id,)).fetchall()
        
        # Get category breakdown
        category_stats = conn.execute('''
            SELECT category, 
                   COUNT(*) as item_count,
                   AVG(frequency) as avg_frequency,
                   AVG(average_interval) as avg_interval
            FROM item_history
            WHERE user_id = ?
            GROUP BY category
            ORDER BY avg_frequency DESC
        ''', (user_id,)).fetchall()
        
        conn.close()
        
        return jsonify({
            'urgency_distribution': [dict(row) for row in urgency_distribution],
            'top_frequent_items': [dict(row) for row in top_frequent],
            'overdue_items': [dict(row) for row in overdue_items],
            'category_stats': [dict(row) for row in category_stats],
            'total_tracked_items': sum(row['count'] for row in urgency_distribution)
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/notifications/pending/<int:user_id>', methods=['GET'])
def get_pending_notifications(user_id):
    """Get items that need notifications"""
    try:
        conn = get_db()
        
        # Get high urgency items that haven't been notified recently
        pending = conn.execute('''
            SELECT h.name, h.category, h.frequency, h.days_since_last_use, h.average_interval,
                   COALESCE(u.urgency_level, 3) as urgency_level,
                   u.notification_enabled,
                   MAX(n.sent_at) as last_notification
            FROM item_history h
            LEFT JOIN item_urgency u ON h.user_id = u.user_id AND h.name = u.item_name AND h.category = u.category
            LEFT JOIN notification_log n ON h.user_id = n.user_id AND h.name = n.item_name
            WHERE h.user_id = ? 
            AND COALESCE(u.urgency_level, 3) >= 3
            AND COALESCE(u.notification_enabled, 1) = 1
            AND (n.sent_at IS NULL OR datetime(n.sent_at, '+24 hours') < datetime('now'))
            GROUP BY h.name, h.category
            ORDER BY COALESCE(u.urgency_level, 3) DESC, h.frequency DESC
        ''', (user_id,)).fetchall()
        
        result = []
        for item in pending:
            overdue_days = max(0, item['days_since_last_use'] - item['average_interval'])
            result.append({
                'name': item['name'],
                'category': item['category'],
                'urgency_level': item['urgency_level'],
                'frequency': item['frequency'],
                'days_overdue': overdue_days,
                'average_interval': item['average_interval'],
                'last_notification': item['last_notification']
            })
        
        conn.close()
        return jsonify(result)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/test')
def test():
    return jsonify({'test': 'working'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000) 
