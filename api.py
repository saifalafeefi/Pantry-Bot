from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3
from datetime import datetime
from typing import List

app = Flask(__name__)
CORS(app)

DB_PATH = 'pantrybot.db'

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute('PRAGMA journal_mode=WAL')
    conn.execute('PRAGMA synchronous=NORMAL')
    
    conn.execute('''
    CREATE TABLE IF NOT EXISTS item_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        use_count INTEGER DEFAULT 1,
        UNIQUE(name, category)
    )
    ''')
    return conn

@app.route('/grocery/items', methods=['GET'])
def get_items():
    conn = get_db()
    items = conn.execute('SELECT * FROM grocery_items ORDER BY created_at DESC').fetchall()
    conn.close()
    return jsonify([dict(item) for item in items])

@app.route('/grocery/items', methods=['POST'])
def add_item():
    data = request.json
    conn = get_db()
    cursor = conn.cursor()
    
    cursor.execute('''
        INSERT INTO item_history (name, category, last_used, use_count)
        VALUES (?, ?, CURRENT_TIMESTAMP, 1)
        ON CONFLICT(name, category) DO UPDATE SET
        last_used = CURRENT_TIMESTAMP,
        use_count = use_count + 1
    ''', (data['name'], data['category']))
    
    cursor.execute(
        'INSERT INTO grocery_items (name, quantity, category, checked, created_at) VALUES (?, ?, ?, 0, ?)',
        (
            data['name'],
            data['quantity'],
            data['category'],
            datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        )
    )
    conn.commit()
    new_id = cursor.lastrowid
    conn.close()
    return jsonify({'id': new_id, 'success': True})

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
    conn = get_db()
    suggestions = conn.execute('''
        SELECT name, category, use_count 
        FROM item_history 
        WHERE LOWER(name) LIKE ? 
        ORDER BY use_count DESC, last_used DESC 
        LIMIT 5
    ''', (f'%{query}%',)).fetchall()
    conn.close()
    return jsonify([dict(item) for item in suggestions])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000) 