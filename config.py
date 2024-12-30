# Database configuration
DB_CONFIG = {
    'path': 'pantrybot.db',
    'backup_path': 'backup/pantrybot.db'
}

# Server configuration
SERVER_CONFIG = {
    'host': '0.0.0.0',
    'port': 5000,
    'debug': False
}

# Security configuration
SECURITY_CONFIG = {
    'password_salt_rounds': 100000,
    'token_expiry_days': 30
} 