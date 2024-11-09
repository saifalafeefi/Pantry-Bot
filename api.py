from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3
from datetime import datetime

app = Flask(__name__)
CORS(app)

DB_PATH = 'pantrybot.db'

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute('PRAGMA journal_mode=WAL')
    conn.execute('PRAGMA synchronous=NORMAL')
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
    cursor.execute(
        'INSERT INTO grocery_items (name, checked, created_at) VALUES (?, 0, ?)',
        (data['name'], datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    )
    conn.commit()
    new_id = cursor.lastrowid
    conn.close()
    return jsonify({'id': new_id, 'success': True})

@app.route('/grocery/items/<int:item_id>', methods=['PUT'])
def toggle_item(item_id):
    try:
        data = request.json
        conn = get_db()
        conn.execute(
            'UPDATE grocery_items SET checked = ? WHERE id = ?',
            (data['checked'], item_id)
        )
        conn.commit()
        conn.close()
        return jsonify({'success': True})
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/grocery/items/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    conn = get_db()
    conn.execute('DELETE FROM grocery_items WHERE id = ?', (item_id,))
    conn.commit()
    conn.close()
    return jsonify({'success': True})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000) 