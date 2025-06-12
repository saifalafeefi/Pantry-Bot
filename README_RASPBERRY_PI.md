# PantryBot Raspberry Pi Server Setup Guide

This guide explains how to set up a Raspberry Pi as a PantryBot server using Apache and Flask. It covers every step, from a fresh Raspberry Pi OS install to a working server accessible via your local network or a custom domain.

---

## Requirements

- Raspberry Pi (any model, Pi 4 recommended)
- Raspberry Pi OS (fresh install recommended)
- Internet connection
- Terminal access (SSH or direct)
- (Optional) Domain name and Cloudflare account for remote access

---

## 1. Update and Install Dependencies

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install apache2 python3-pip python3-venv git sqlite3 -y
sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod headers
```

---

## 2. Create Project Directory

```bash
cd /home/$(whoami)
mkdir pantrybot
cd pantrybot
sudo mkdir -p /var/www/pantrybot
sudo chown $(whoami):$(whoami) /var/www/pantrybot
```

---

## 3. Set Up Python Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install flask flask-cors
```

---

## 4. Create API Server File

Create a file called `api.py` in your `pantrybot` directory. Paste the full PantryBot Flask API code here. (If you don't have it, ask the maintainer or copy from your backup.)

---

## 5. Create Configuration File

Create a file called `config.py` in the same directory with the following content:

```python
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
```

---

## 6. Create a Basic Web Index

```bash
tee /var/www/pantrybot/index.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>PantryBot Server</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .api-link { color: #007bff; text-decoration: none; }
        .api-link:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1>🤖 PantryBot Server</h1>
    <p>Server is running and ready to accept requests.</p>
    <h2>API Endpoints</h2>
    <ul>
        <li><a href="/auth/login" class="api-link">POST /auth/login</a> - User login</li>
        <li><a href="/users" class="api-link">GET /users</a> - List users</li>
        <li><a href="/grocery/items" class="api-link">GET /grocery/items</a> - Get grocery items</li>
        <li><a href="/pantry/items" class="api-link">GET /pantry/items</a> - Get pantry items</li>
    </ul>
    <p><strong>Default Users:</strong></p>
    <ul>
        <li>Username: <code>admin</code>, Password: <code>TheReal360</code> (Admin)</li>
        <li>Username: <code>whitehouse</code>, Password: <code>Adnoc2003</code> (Regular User)</li>
    </ul>
</body>
</html>
EOF
```

---

## 7. Apache Configuration

```bash
sudo tee /etc/apache2/sites-available/pantrybot.conf > /dev/null <<EOF
<VirtualHost *:8080>
    ServerName yourdomain.com
    DocumentRoot /var/www/pantrybot
    <Directory /var/www/pantrybot>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
    ProxyPreserveHost On
    ProxyPass /auth/ http://localhost:5000/auth/
    ProxyPassReverse /auth/ http://localhost:5000/auth/
    ProxyPass /grocery/ http://localhost:5000/grocery/
    ProxyPassReverse /grocery/ http://localhost:5000/grocery/
    ProxyPass /pantry/ http://localhost:5000/pantry/
    ProxyPassReverse /pantry/ http://localhost:5000/pantry/
    ProxyPass /users http://localhost:5000/users
    ProxyPassReverse /users http://localhost:5000/users
</VirtualHost>
<VirtualHost *:8443>
    ServerName yourdomain.com
    DocumentRoot /var/www/pantrybot
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/pantrybot.crt
    SSLCertificateKeyFile /etc/ssl/private/pantrybot.key
    <Directory /var/www/pantrybot>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
    ProxyPreserveHost On
    ProxyPass /auth/ http://localhost:5000/auth/
    ProxyPassReverse /auth/ http://localhost:5000/auth/
    ProxyPass /grocery/ http://localhost:5000/grocery/
    ProxyPassReverse /grocery/ http://localhost:5000/grocery/
    ProxyPass /pantry/ http://localhost:5000/pantry/
    ProxyPassReverse /pantry/ http://localhost:5000/pantry/
    ProxyPass /users http://localhost:5000/users
    ProxyPassReverse /users http://localhost:5000/users
</VirtualHost>
EOF
```

Add ports to Apache:

```bash
sudo tee -a /etc/apache2/ports.conf > /dev/null <<EOF
Listen 8080
Listen 8443
EOF
```

---

## 8. Generate SSL Certificates (Self-Signed)

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/pantrybot.key \
    -out /etc/ssl/certs/pantrybot.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=yourdomain.com"
```

---

## 9. Enable Apache Site and Restart

```bash
sudo a2ensite pantrybot
sudo a2dissite 000-default
sudo systemctl reload apache2
sudo systemctl restart apache2
```

---

## 10. Create Systemd Service for API

```bash
sudo tee /etc/systemd/system/pantrybot-api.service > /dev/null <<EOF
[Unit]
Description=PantryBot Flask API
After=network.target
[Service]
Type=simple
User=$(whoami)
WorkingDirectory=/home/$(whoami)/pantrybot
Environment=PATH=/home/$(whoami)/pantrybot/venv/bin
ExecStart=/home/$(whoami)/pantrybot/venv/bin/python api.py
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
```

---

## 11. Initialize Database (First Run)

```bash
source venv/bin/activate
python3 api.py
# Or, if you want to just create the DB file:
python3 -c "import sqlite3; conn = sqlite3.connect('pantrybot.db'); conn.close()"
```

---

## 12. Enable and Start Services

```bash
sudo systemctl daemon-reload
sudo systemctl enable pantrybot-api
sudo systemctl start pantrybot-api
sudo systemctl enable apache2
sudo systemctl restart apache2
```

---

## 13. Test Everything

```bash
curl http://localhost:5000/users
curl http://localhost:8080
```

You should see a JSON list of users and the PantryBot HTML page.

---

## 14. (Optional) Port Forwarding and Domain Setup

- Forward ports 8080 and 8443 from your router to your Pi's local IP.
- Set up an A record in your DNS provider (e.g., Cloudflare) pointing your domain/subdomain to your public IP.
- Use your domain in the Apache config (`ServerName`).

---

## Troubleshooting

- If you get permission errors, check file ownership and permissions.
- If the API doesn't start, check `sudo systemctl status pantrybot-api` and `journalctl -u pantrybot-api`.
- If Apache doesn't serve on 8080/8443, check your site config and that the ports are open.
- For HTTPS, browsers may warn about self-signed certs. Use a real cert for production.

---

## Default Users

- **Admin:** Username: `admin` / Password: `TheReal360`
- **User:** Username: `whitehouse` / Password: `Adnoc2003`

---

## Support

If you get stuck, check the logs or ask the maintainer for help. This guide is designed to be copy-paste friendly and complete for a fresh Raspberry Pi OS install. 