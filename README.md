# 🤖 PantryBot - Smart Kitchen Assistant

A comprehensive Raspberry Pi and Flutter-based system for managing pantry items, recipes, and grocery lists. Perfect for families who want to stay organized in the kitchen!

## 🚀 Features

- **📱 Cross-Platform App**: Flutter mobile app for iOS/Android
- **🖥️ Raspberry Pi Interface**: Touch-friendly desktop interface
- **🛒 Smart Grocery Lists**: Multi-user grocery management with suggestions
- **🍳 Recipe Management**: Store and organize your favorite recipes
- **📊 Item Tracking**: Track pantry items with expiration dates
- **👥 Multi-User Support**: Family accounts with individual preferences
- **⚡ Quick Actions**: Swipe gestures and touch controls for lightning-fast interactions

## 🛠️ Installation & Setup

### Prerequisites
- **Raspberry Pi 4** (recommended) with Raspberry Pi OS
- **Python 3.8+** installed
- **Flutter SDK** (for mobile app development)
- **SQLite3** (usually pre-installed)

### Raspberry Pi Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/Pantry-Bot.git
   cd Pantry-Bot
   ```

2. **Install Python dependencies:**
   ```bash
   pip3 install flask flask-cors sqlite3 tkcalendar
   ```

3. **Set up the database:**
   ```bash
   python3 api.py
   # This will create the database and default users
   ```

4. **Configure your network:**
   - Edit `config.py` to set your preferred host/port
   - Update the domain in `pantrybot/lib/main.dart` (line 75) to your Pi's IP address

5. **Start the services:**
   ```bash
   # Terminal 1: Start the API server
   python3 api.py

   # Terminal 2: Start the Pi interface (optional)
   python3 pantrybot.py
   ```

### Mobile App Setup

1. **Install Flutter** (if not already installed):
   - Follow instructions at [flutter.dev](https://flutter.dev/docs/get-started/install)

2. **Navigate to the Flutter project:**
   ```bash
   cd pantrybot/
   ```

3. **Get dependencies:**
   ```bash
   flutter pub get
   ```

4. **Update the server URL:**
   - Edit `lib/main.dart` line 75: Replace `'https://pantrybot.anonstorage.org:8443'` with your Pi's IP
   - Format: `'http://YOUR_PI_IP:5000'`

5. **Run the app:**
   ```bash
   flutter run
   # Or build for release: flutter build apk
   ```

## 🔧 Recent Updates & Fixes

**Authentication System Overhaul:**
- Fixed password hashing iteration mismatch causing 500/401 login errors
- Resolved database password hash corruption issues
- Improved login error handling with better debugging information

**Admin Panel Restoration:**
- Recreated admin panel with expandable user list interface
- Added admin button (shield icon) to main app interface for easy access
- Admin can now view all users and their individual grocery items
- Color-coded user status (admin vs regular users)

**Database Schema Updates:**
- Added missing `frequency` and `user_id` columns to item_history table
- Fixed database compatibility issues with newer code versions
- Improved item suggestion system with usage tracking

**Performance Improvements:**
- Switched to local Pi IP addressing for faster response times
- Reduced connection timeouts and improved error handling
- Better SSL certificate handling for development environments

## 📱 User Manual

### 🔐 Login & User Management

**Logging In:**
1. Open the PantryBot app
2. Enter your username and password
3. Tap "Login"

**Admin Features:**
- Create new user accounts
- View all users' data
- Access global item suggestions

### 🛒 Grocery List Management

#### Adding Items

**Method 1: Quick Add**
1. Type item name in the input field at top
2. Tap the "+" button
3. Adjust quantity and select category
4. Tap "Add"

**Method 2: Smart Suggestions**
1. Start typing an item name
2. Select from suggested items (shows usage history)
3. Item will auto-fill with previous category

#### Quick Actions (NEW! ⚡)

**Swipe Right → Check/Uncheck Items**
- Swipe any item from left to right
- Green background appears
- Instantly toggles check status
- Shows "Undo" option

**Swipe Left → Delete Items**
- Swipe any item from right to left  
- Red background appears
- Confirms before deleting
- Shows deletion confirmation

**Long Press → Quick Edit**
- Press and hold any item
- Opens edit dialog instantly
- Modify name, quantity, or category

**Double Tap → Quick Toggle**
- Double-tap any item
- Instantly checks/unchecks without confirmation
- Provides haptic feedback

**Pull Down → Refresh**
- Pull down on the list
- Refreshes all items from server
- Syncs with other users

#### Searching & Filtering

**Search:**
- Use the search bar to find specific items
- Searches by item name
- Results update as you type

**Sorting Options:**
- Tap the filter icon (☰) in top-right
- Choose from:
  - **Unchecked**: Shows unchecked items first
  - **A to Z**: Alphabetical order
  - **Z to A**: Reverse alphabetical
  - **Newest**: Recently added first
  - **Oldest**: Oldest items first
  - **Filter by Category**: Shows category-specific view

**Category Filtering:**
1. Tap filter icon → "Filter by Category"
2. Select a category (Vegetables, Fruits, etc.)
3. Selected category items appear at top
4. Tap "All Categories" to reset

#### Item Categories
- 🥬 **Vegetables**: Fresh produce, leafy greens
- 🍎 **Fruits**: Fresh and dried fruits
- 🥛 **Dairy**: Milk, cheese, yogurt, eggs
- 🥩 **Meats**: Beef, chicken, fish, deli items
- 🌾 **Grains**: Rice, pasta, bread, cereals
- 🍰 **Sweets**: Candy, desserts, baking items
- 🫒 **Oils**: Cooking oils, vinegars, condiments
- 📱 **Electronics**: Batteries, tech accessories
- 🥤 **Drinks**: Beverages, juices, water
- 💊 **Medicine**: Health and pharmacy items
- 🧽 **Cleaning**: Household cleaning supplies
- 📦 **Other**: Miscellaneous items

### 🖥️ Raspberry Pi Desktop Interface

**Main Menu:**
- **Items**: Manage pantry inventory with expiration tracking
- **Menus**: Store and organize recipes
- **Grocery List**: Same functionality as mobile app
- **System Controls**: Shutdown, restart, sleep functions

**Navigation:**
- Touch-friendly buttons
- Search functionality in each section
- Back buttons to return to main menu

**System Features:**
- **Sleep Mode**: Turns off Pi display, tap to wake
- **Shutdown/Restart**: Safe system power controls
- **Auto-refresh**: Lists update automatically

### 🍳 Recipe Management (Pi Interface)

**Adding Recipes:**
1. Go to "Menus" section
2. Click "Add Recipe"
3. Fill in:
   - Title and Author
   - Description
   - Prep time (minutes)
   - Cook time (minutes)
4. Click "Add Recipe"

**Managing Recipes:**
- **Search**: Find recipes by title or author
- **Edit**: Modify recipe details
- **Delete**: Remove recipes with confirmation

### 📊 Item Tracking (Pi Interface)

**Adding Pantry Items:**
1. Go to "Items" section
2. Click "Add Item"
3. Enter:
   - Item name
   - Category (dropdown)
   - Quantity (use +/- buttons)
   - Expiry date (calendar picker)
4. Click "Add Item"

**Item Management:**
- Items sorted by expiration date (closest first)
- Edit items to update quantities/dates
- Delete expired or consumed items
- Search by item name

## 🔧 Advanced Configuration

### Network Setup
1. Edit `config.py` for server settings
2. Update Flutter app's `baseUrl` in `main.dart`
3. Ensure firewall allows port 5000 (or your configured port)

### Database Backup
- Database file: `pantrybot.db`
- Backup regularly: `cp pantrybot.db backup/pantrybot_$(date +%Y%m%d).db`

### Security Notes
- Change default passwords after first login
- Consider setting up HTTPS for external access
- Raspberry Pi should be on trusted network

## 🎯 Tips for Best Experience

1. **Start with the Tutorial**: Tap the help (?) icon to learn gestures
2. **Use Smart Suggestions**: The app learns your habits and suggests frequently used items
3. **Family Coordination**: Each family member should have their own account
4. **Regular Updates**: Pull down to refresh and sync with other users
5. **Quick Shopping**: Use swipe gestures while shopping for fastest interactions
6. **Category Organization**: Keep items properly categorized for better color coding

## 🐛 Troubleshooting

**App won't connect to Pi:**
- Check Pi IP address in app settings
- Ensure Pi is on same network
- Verify API server is running (`python3 api.py`)

**Gestures not working:**
- Update Flutter app to latest version
- Restart the app
- Check device touch sensitivity

**Database issues:**
- Stop all services
- Check `pantrybot.db` file permissions
- Restart API server

**Future Enhancement Ideas:**
- Barcode scanning
- Recipe suggestions based on available items  
- Shopping list sharing via QR codes
- Voice commands
- Meal planning calendar

---

*This was an inspiration from my beloved family, and I wish to continue improving this until satisfaction.*