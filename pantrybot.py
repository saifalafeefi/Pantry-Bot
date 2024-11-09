import tkinter as tk
from tkinter import ttk, messagebox
from tkcalendar import DateEntry
import os, platform, subprocess, time, dbus
import sqlite3
from datetime import datetime

# Ensure database connection
conn = sqlite3.connect('pantrybot.db')
cursor = conn.cursor()

# Create tables for items and recipes
cursor.execute('''
CREATE TABLE IF NOT EXISTS items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    entry_date TEXT NOT NULL,
    expiry_date TEXT NOT NULL
)
''')

cursor.execute('''
CREATE TABLE IF NOT EXISTS recipes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    description TEXT,
    prep_time INTEGER,
    cook_time INTEGER
)
''')

# Add new table for grocery items
cursor.execute('''
CREATE TABLE IF NOT EXISTS grocery_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    checked INTEGER DEFAULT 0,
    created_at TEXT NOT NULL
)
''')

conn.commit()

class FridgeManagerApp(tk.Tk):  # Use tk instead of Tk
    def __init__(self):
        super().__init__()
        self.title("Pantry Bot")
        
        # Get screen dimensions
        screen_width = self.winfo_screenwidth()
        screen_height = self.winfo_screenheight()
        
        # Set window size to slightly smaller than screen
        self.geometry(f"{screen_width}x{screen_height-30}")  # -30 to show top bar
        
        # Container to hold all widgets
        self.container = tk.Frame(self)
        self.container.pack(fill=tk.BOTH, expand=True)
        
        # Start with main menu
        self.show_main_menu()

    def show_main_menu(self):
        # Clear the existing content
        for widget in self.container.winfo_children():
            widget.destroy()

        # Create a frame for the welcome message
        welcome_frame = tk.Frame(self.container)
        welcome_frame.pack(pady=60)

        # Add the welcome message
        welcome_label = tk.Label(welcome_frame, text="Welcome to PantryBot!", font=('Arial', 28, 'bold'))
        welcome_label.pack()

        # Create a frame for the main buttons
        main_frame = tk.Frame(self.container)
        main_frame.pack(expand=True, pady=0)

        # Items, Menus, and Grocery buttons side by side
        self.items_button = tk.Button(main_frame, text="Items", command=self.show_items, font=('Arial', 20))
        self.items_button.pack(side=tk.LEFT, padx=10)

        self.menus_button = tk.Button(main_frame, text="Menus", command=self.show_menus, font=('Arial', 20))
        self.menus_button.pack(side=tk.LEFT, padx=10)

        self.grocery_button = tk.Button(main_frame, text="Grocery List", command=self.show_grocery, font=('Arial', 20))
        self.grocery_button.pack(side=tk.LEFT, padx=10)

        # Create a frame for the system buttons below the main buttons
        system_frame = tk.Frame(self.container)
        system_frame.pack(pady=40)

        # System buttons directly below the main buttons
        self.shutdown_button = tk.Button(system_frame, text="Shutdown", command=self.shutdown, font=('Arial', 12))
        self.shutdown_button.pack(side=tk.LEFT, padx=5, pady=5)

        self.restart_button = tk.Button(system_frame, text="Restart", command=self.restart, font=('Arial', 12))
        self.restart_button.pack(side=tk.LEFT, padx=5, pady=5)

        self.sleep_button = tk.Button(system_frame, text="Sleep", command=self.sleep, font=('Arial', 12))
        self.sleep_button.pack(side=tk.LEFT, padx=5, pady=5)

    def show_items(self):
        # Clear the existing content
        for widget in self.container.winfo_children():
            widget.destroy()

        # Add the title
        self.title_label = tk.Label(self.container, text="Items Section", font=('Arial', 24))
        self.title_label.pack(pady=10)

        # Search bar and button
        self.search_frame = tk.Frame(self.container)
        self.search_frame.pack(pady=10)

        search_label = tk.Label(self.search_frame, text="Search:", font=('Arial', 14))
        search_label.pack(side=tk.LEFT, padx=5)

        self.search_entry = tk.Entry(self.search_frame, font=('Arial', 14), width=400)
        self.search_entry.pack(side=tk.LEFT, padx=5)

        search_button = tk.Button(self.search_frame, text="Search", font=('Arial', 14), command=lambda: self.search_items(self.search_entry.get()))
        search_button.pack(side=tk.LEFT, padx=5)

        # Frame for control buttons at the bottom, centered
        self.control_frame = tk.Frame(self.container)
        self.control_frame.pack(pady=20)

        # Add the "Add Item" button and hide the keyboard when pressed
        add_button = tk.Button(self.control_frame, text="Add Item", font=('Arial', 16), command=lambda: [self.show_item_form_for_adding()])
        add_button.pack(side=tk.LEFT, padx=10)

        # Add the "Back to Main Menu" button and hide the keyboard when pressed
        back_button = tk.Button(self.control_frame, text="Back to Main Menu", font=('Arial', 16), command=self.show_main_menu)
        back_button.pack(side=tk.LEFT, padx=10)

        # Center the control frame
        self.control_frame.pack(anchor=tk.CENTER)

        # Add scrollable frame for menus
        scrollable_frame = tk.Frame(self.container)
        scrollable_frame.pack(fill=tk.BOTH, expand=True)
        self.items_display_frame = self.add_scrollbar_to_frame(scrollable_frame)

        # Populate the items into the display frame
        self.populate_items()

    def populate_items(self):
        # Clear the items_display_frame
        for widget in self.items_display_frame.winfo_children():
            widget.destroy()

        items_per_row = 3  # Set to 3 items per row
        row = 0
        col = 0

        cursor.execute("SELECT * FROM items ORDER BY expiry_date ASC")
        items = cursor.fetchall()

        # Configure the columns to stretch equally
        for i in range(items_per_row + 2):  # Include the extra columns for centering
            self.items_display_frame.grid_columnconfigure(i, weight=1)

        for item in items:
            # Replace tk.Frame with tk.Frame
            item_frame = tk.Frame(self.items_display_frame)
            item_frame.grid(row=row, column=col + 1, padx=20, pady=20, sticky="ew")  # Add column offset (+1) for centering

            # Replace tk.Label with tk.Label
            item_name = tk.Label(item_frame, text=item[1], font=('Arial', 14))
            item_name.pack(pady=5)

            item_details = tk.Label(item_frame, text=f"Type: {item[2]}\nQty: {item[3]}\nExpires: {item[5]}", font=('Arial', 12))
            item_details.pack(pady=5)

            # Buttons should use tk.Button
            button_frame = tk.Frame(item_frame)
            button_frame.pack(pady=5)

            edit_button = tk.Button(button_frame, text="Edit", command=lambda i=item: self.show_item_form_for_editing(i))
            edit_button.pack(side=tk.LEFT, padx=5)

            delete_button = tk.Button(button_frame, text="Delete", command=lambda i=item: self.confirm_delete_item(i))
            delete_button.pack(side=tk.LEFT, padx=5)

            col += 1
            if col >= items_per_row:
                col = 0
                row += 1

        # Add an empty column at the end to ensure it's centered
        self.items_display_frame.grid_columnconfigure(items_per_row + 1, weight=1)

        # Ensure all rows are adaptive
        for i in range(row + 1):
            self.items_display_frame.grid_rowconfigure(i, weight=1)

    def search_items(self, search_term):
        # Clear the items_display_frame only
        for widget in self.items_display_frame.winfo_children():
            widget.destroy()

        items_per_row = 3
        row = 0
        col = 0

        # Adjust query based on whether a search term is provided
        if search_term.strip() == "":
            # No search term provided, prioritize by expiry date
            cursor.execute("SELECT * FROM items ORDER BY expiry_date ASC")
        else:
            # Search for items matching the search term and sort alphabetically
            cursor.execute("SELECT * FROM items WHERE name LIKE ? ORDER BY name ASC", ('%' + search_term + '%',))

        items = cursor.fetchall()

        for item in items:
            item_frame = tk.Frame(self.items_display_frame)
            item_frame.grid(row=row, column=col + 1, padx=10, pady=10, sticky="ew")

            item_name = tk.Label(item_frame, text=item[1], font=('Arial', 14))
            item_name.pack(pady=5)

            item_details = tk.Label(item_frame, text=f"Type: {item[2]}\nQty: {item[3]}\nExpires: {item[5]}", font=('Arial', 12))
            item_details.pack(pady=5)

            # Edit and Delete buttons
            button_frame = tk.Frame(item_frame)
            button_frame.pack(pady=5)

            edit_button = tk.Button(button_frame, text="Edit", font=('Arial', 10), command=lambda i=item: self.show_item_form_for_editing(i))
            edit_button.pack(side=tk.LEFT, padx=5)

            delete_button = tk.Button(button_frame, text="Delete", font=('Arial', 10), command=lambda i=item: self.confirm_delete_item(i))
            delete_button.pack(side=tk.LEFT, padx=5)

            col += 1
            if col >= items_per_row:
                col = 0
                row += 1

        self.items_display_frame.grid_columnconfigure(items_per_row + 1, weight=1)
        for i in range(row + 1):
            self.items_display_frame.grid_rowconfigure(i, weight=1)

    def confirm_delete_item(self, item):
        confirm = messagebox.askyesno("Delete Item", f"Are you sure you want to delete {item[1]}?")
        if confirm:
            cursor.execute("DELETE FROM items WHERE id=?", (item[0],))
            conn.commit()
            messagebox.showinfo("Success", f"Item '{item[1]}' was deleted successfully!")
            self.show_items()

    def show_item_form_for_editing(self, item):
        # Clear the existing content
        for widget in self.container.winfo_children():
            widget.destroy()

        # Centered and larger form for editing items
        form_frame = tk.Frame(self.container)
        form_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER)

        tk.Label(form_frame, text="Name:", font=('Arial', 14)).grid(row=0, column=0, padx=10, pady=10)
        self.name_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.name_entry.insert(0, item[1])
        self.name_entry.grid(row=0, column=1, padx=10, pady=10)

        tk.Label(form_frame, text="Type:", font=('Arial', 14)).grid(row=1, column=0, padx=10, pady=10)
        self.type_entry = ttk.Combobox(form_frame, font=('Arial', 14), values=["Dairy", "Meat", "Vegetables", "Fruits", "Grains", "Sweets", "Oils"])
        self.type_entry.set(item[2])
        self.type_entry.grid(row=1, column=1, padx=10, pady=10)

        # Quantity Label
        tk.Label(form_frame, text="Quantity:", font=('Arial', 14)).grid(row=2, column=0, padx=10, pady=10)

        # Frame to hold the quantity display and buttons
        quantity_frame = tk.Frame(form_frame)
        quantity_frame.grid(row=2, column=1, padx=10, pady=10)

        # Decrement Button
        decrement_button = tk.Button(quantity_frame, text="–", font=('Arial', 20), width=3, command=self.decrement_quantity)
        decrement_button.pack(side=tk.LEFT, padx=5)

        # Quantity Display (Read-only Entry)
        self.quantity_var = tk.IntVar(value=item[3])  # Initialize quantity to current value
        self.quantity_display = tk.Entry(quantity_frame, font=('Arial', 14), width=5, textvariable=self.quantity_var, state='readonly', justify='center')
        self.quantity_display.pack(side=tk.LEFT, padx=5)

        # Increment Button
        increment_button = tk.Button(quantity_frame, text="+", font=('Arial', 20), width=3, command=self.increment_quantity)
        increment_button.pack(side=tk.LEFT, padx=5)



        tk.Label(form_frame, text="Expiry Date:", font=('Arial', 14)).grid(row=3, column=0, padx=10, pady=10)
        self.expiry_entry = DateEntry(form_frame, font=('Arial', 14), date_pattern='yyyy-mm-dd', state='readonly')
        self.expiry_entry.set_date(item[5])  # Set the DateEntry to the item's current expiry date
        self.expiry_entry.grid(row=3, column=1, padx=10, pady=10)


        button_frame = tk.Frame(form_frame)
        button_frame.grid(row=4, column=0, columnspan=2, pady=20)

        save_button = tk.Button(button_frame, text="Save Changes", font=('Arial', 14), command=lambda: self.save_item_changes(item[0]))
        save_button.pack(side=tk.LEFT, padx=10)

        cancel_button = tk.Button(button_frame, text="Cancel", font=('Arial', 14), command=self.show_items)
        cancel_button.pack(side=tk.LEFT, padx=10)

    def save_item_changes(self, item_id):
        name = self.name_entry.get()
        type_ = self.type_entry.get()
        quantity = self.quantity_var.get()
        expiry_date = self.expiry_entry.get_date().strftime('%Y-%m-%d')

        if not name or not type_ or not quantity or not expiry_date:
            messagebox.showerror("Input Error", "All fields must be filled out.")
            return

        try:
            quantity = int(quantity)
        except ValueError:
            messagebox.showerror("Input Error", "Quantity must be an integer.")
            return

        cursor.execute("""
            UPDATE items
            SET name = ?, type = ?, quantity = ?, expiry_date = ?
            WHERE id = ?
        """, (name, type_, quantity, expiry_date, item_id))
        conn.commit()

        messagebox.showinfo("Success", "Item updated successfully!")
        self.show_items()

    def show_item_form_for_adding(self):
        for widget in self.container.winfo_children():
            widget.destroy()

        form_frame = tk.Frame(self.container)
        form_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER)

        tk.Label(form_frame, text="Name:", font=('Arial', 14)).grid(row=0, column=0, padx=10, pady=10)
        self.name_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.name_entry.grid(row=0, column=1, padx=10, pady=10)

        tk.Label(form_frame, text="Category:", font=('Arial', 14)).grid(row=1, column=0, padx=10, pady=10)
        self.type_entry = ttk.Combobox(form_frame, font=('Arial', 14), 
                            values=["Dairy", "Meat", "Vegetables", "Fruits", "Grains", "Sweets", "Oils"], 
                            state='readonly')

        self.type_entry.grid(row=1, column=1, padx=10, pady=10)

        # Quantity Label
        tk.Label(form_frame, text="Quantity:", font=('Arial', 14)).grid(row=2, column=0, padx=10, pady=10)

        # Frame to hold the quantity display and buttons
        quantity_frame = tk.Frame(form_frame)
        quantity_frame.grid(row=2, column=1, padx=10, pady=10)

        # Decrement Button
        decrement_button = tk.Button(quantity_frame, text="–", font=('Arial', 20), width=3, command=self.decrement_quantity)
        decrement_button.pack(side=tk.LEFT, padx=5)

        # Quantity Display (Read-only Entry)
        self.quantity_var = tk.IntVar(value=0)  # Initialize quantity to 0
        self.quantity_display = tk.Entry(quantity_frame, font=('Arial', 14), width=5, textvariable=self.quantity_var, state='readonly', justify='center')
        self.quantity_display.pack(side=tk.LEFT, padx=5)

        # Increment Button
        increment_button = tk.Button(quantity_frame, text="+", font=('Arial', 20), width=3, command=self.increment_quantity)
        increment_button.pack(side=tk.LEFT, padx=5)

        # Use DateEntry for the expiry date field
        tk.Label(form_frame, text="Expiry Date:", font=('Arial', 14)).grid(row=3, column=0, padx=10, pady=10)
        self.expiry_entry = DateEntry(form_frame, font=('Arial', 14), date_pattern='yyyy-mm-dd', state='readonly')  # Date picker
        self.expiry_entry.grid(row=3, column=1, padx=10, pady=10)

        button_frame = tk.Frame(form_frame)
        button_frame.grid(row=4, column=0, columnspan=2, pady=20)

        add_button = tk.Button(button_frame, text="Add Item", font=('Arial', 14), command=self.add_item)
        add_button.pack(side=tk.LEFT, padx=10)

        cancel_button = tk.Button(button_frame, text="Cancel", font=('Arial', 14), command=self.show_items)
        cancel_button.pack(side=tk.LEFT, padx=10)

    def increment_quantity(self):
        current_quantity = self.quantity_var.get()
        self.quantity_var.set(current_quantity + 1)

    def decrement_quantity(self):
        current_quantity = self.quantity_var.get()
        if current_quantity > 0:
            self.quantity_var.set(current_quantity - 1)

    def add_item(self):
        name = self.name_entry.get()
        type_ = self.type_entry.get()
        quantity = self.quantity_var.get()
        expiry_date = self.expiry_entry.get_date().strftime('%Y-%m-%d')  # Get selected date as a string

        if not name or not type_ or not quantity or not expiry_date:
            messagebox.showerror("Input Error", "All fields must be filled out.")
            return

        try:
            quantity = int(quantity)  # Convert quantity to integer
        except ValueError:
            messagebox.showerror("Input Error", "Quantity must be an integer.")
            return

        cursor.execute("""
            INSERT INTO items (name, type, quantity, entry_date, expiry_date)
            VALUES (?, ?, ?, ?, ?)
        """, (name, type_, quantity, datetime.now().strftime("%Y-%m-%d"), expiry_date))
        conn.commit()

        messagebox.showinfo("Success", "Item added successfully!")
        self.show_items()

    def show_menus(self):
        # Clear the existing content
        for widget in self.container.winfo_children():
            widget.destroy()

        # Add the title
        self.title_label = tk.Label(self.container, text="Menus Section", font=('Arial', 24))
        self.title_label.pack(pady=10)

        # Search bar and button
        self.search_frame = tk.Frame(self.container)
        self.search_frame.pack(pady=10)

        search_label = tk.Label(self.search_frame, text="Search:", font=('Arial', 14))
        search_label.pack(side=tk.LEFT, padx=5)

        self.search_entry = tk.Entry(self.search_frame, font=('Arial', 14))
        self.search_entry.pack(side=tk.LEFT, padx=5)

        search_button = tk.Button(self.search_frame, text="Search", font=('Arial', 14),
                             command=lambda: self.search_recipes(self.search_entry.get()))
        search_button.pack(side=tk.LEFT, padx=5)

        # Frame for control buttons
        self.control_frame = tk.Frame(self.container)
        self.control_frame.pack(pady=20)

        add_button = tk.Button(self.control_frame, text="Add Recipe", font=('Arial', 16),
                          command=lambda: [self.show_recipe_form_for_adding()])
        add_button.pack(side=tk.LEFT, padx=10)

        back_button = tk.Button(self.control_frame, text="Back to Main Menu", font=('Arial', 16),
                           command=self.show_main_menu)
        back_button.pack(side=tk.LEFT, padx=10)

        # Add scrollable frame for menus
        scrollable_frame = tk.Frame(self.container)
        scrollable_frame.pack(fill=tk.BOTH, expand=True)
        self.menus_display_frame = self.add_scrollbar_to_frame(scrollable_frame)

        # Populate the menus
        self.populate_menus()

    def populate_menus(self):
        menus_per_row = 3  # Set to 3 menus per row
        row = 0
        col = 0
        
        cursor.execute("SELECT * FROM recipes ORDER BY title ASC")
        menus = cursor.fetchall()
        
        # Configure grid columns
        for i in range(menus_per_row):
            self.menus_display_frame.grid_columnconfigure(i, weight=1)
        
        for menu in menus:
            menu_frame = tk.Frame(self.menus_display_frame)
            menu_frame.grid(row=row, column=col, padx=20, pady=20, sticky="nsew")

            title = tk.Label(menu_frame, text=menu[1], font=('Arial', 16, 'bold'))
            title.pack(anchor='w')

            details = tk.Label(menu_frame, 
                              text=f"By: {menu[2]}\nPrep: {menu[4]} min | Cook: {menu[5]} min\n{menu[3]}", 
                              font=('Arial', 12))
            details.pack(anchor='w')

            button_frame = tk.Frame(menu_frame)
            button_frame.pack(fill=tk.X, pady=5)

            edit_btn = tk.Button(button_frame, text="Edit", 
                                command=lambda r=menu: self.show_recipe_form_for_editing(r))
            edit_btn.pack(side=tk.LEFT, padx=5)

            delete_btn = tk.Button(button_frame, text="Delete", 
                                   command=lambda r=menu: self.confirm_delete_recipe(r))
            delete_btn.pack(side=tk.LEFT, padx=5)
            
            col += 1
            if col >= menus_per_row:
                col = 0
                row += 1

    def search_recipes(self, search_term):
        for widget in self.menus_display_frame.winfo_children():
            widget.destroy()

        recipes_per_row = 3
        row = 0
        col = 0

        if search_term.strip() == "":
            cursor.execute("SELECT * FROM recipes ORDER BY title ASC")
        else:
            cursor.execute("""
                SELECT * FROM recipes
                WHERE title LIKE ? OR author LIKE ?
                ORDER BY title ASC
            """, ('%' + search_term + '%', '%' + search_term + '%'))

        recipes = cursor.fetchall()

        for recipe in recipes:
            recipe_frame = tk.Frame(self.menus_display_frame)
            recipe_frame.grid(row=row, column=col, padx=20, pady=20, sticky="ew")

            recipe_title = tk.Label(recipe_frame, text=recipe[1], font=('Arial', 14, 'bold'))
            recipe_title.pack(pady=5)

            recipe_author = tk.Label(recipe_frame, text=f"Author: {recipe[2]}", font=('Arial', 12))
            recipe_author.pack(pady=5)

            recipe_description = tk.Label(recipe_frame, text=f"Description: {recipe[3]}", font=('Arial', 12), wraplength=200)
            recipe_description.pack(pady=5)

            recipe_times = tk.Label(recipe_frame, text=f"Prep Time: {recipe[4]} mins\nCook Time: {recipe[5]} mins", font=('Arial', 12))
            recipe_times.pack(pady=5)

            button_frame = tk.Frame(recipe_frame)
            button_frame.pack(pady=5)

            edit_button = tk.Button(button_frame, text="Edit", font=('Arial', 10), command=lambda r=recipe: self.show_recipe_form_for_editing(r))
            edit_button.pack(side=tk.LEFT, padx=5)

            delete_button = tk.Button(button_frame, text="Delete", font=('Arial', 10), command=lambda r=recipe: self.confirm_delete_recipe(r))
            delete_button.pack(side=tk.LEFT, padx=5)

            col += 1
            if col >= recipes_per_row:
                col = 0
                row += 1

        for i in range(recipes_per_row):
            self.menus_display_frame.grid_columnconfigure(i, weight=1)
        for i in range(row + 1):
            self.menus_display_frame.grid_rowconfigure(i, weight=1)

    def add_recipe(self):
        title = self.title_entry.get()
        author = self.author_entry.get()
        description = self.description_entry.get()
        prep_time = self.prep_time_entry.get()
        cook_time = self.cook_time_entry.get()

        if not title or not author or not prep_time or not cook_time:
            messagebox.showerror("Input Error", "All fields must be filled out.")
            return

        try:
            prep_time = int(prep_time)
            cook_time = int(cook_time)
        except ValueError:
            messagebox.showerror("Input Error", "Prep Time and Cook Time must be integers.")
            return

        cursor.execute("""
            INSERT INTO recipes (title, author, description, prep_time, cook_time)
            VALUES (?, ?, ?, ?, ?)
        """, (title, author, description, prep_time, cook_time))
        conn.commit()

        messagebox.showinfo("Success", "Recipe added successfully!")
        self.show_menus()

    def confirm_delete_recipe(self, recipe):
        confirm = messagebox.askyesno("Delete Recipe", f"Are you sure you want to delete '{recipe[1]}' by {recipe[2]}?")
        if confirm:
            cursor.execute("DELETE FROM recipes WHERE id=?", (recipe[0],))
            conn.commit()
            messagebox.showinfo("Success", f"Recipe '{recipe[1]}' was deleted successfully!")
            self.show_menus()

    def show_recipe_form_for_adding(self):
        for widget in self.container.winfo_children():
            widget.destroy()

        form_frame = tk.Frame(self.container)
        form_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER)

        tk.Label(form_frame, text="Title:", font=('Arial', 14)).grid(row=0, column=0, padx=10, pady=10)
        self.title_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.title_entry.grid(row=0, column=1, padx=10, pady=10)

        tk.Label(form_frame, text="Author:", font=('Arial', 14)).grid(row=1, column=0, padx=10, pady=10)
        self.author_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.author_entry.grid(row=1, column=1, padx=10, pady=10)

        tk.Label(form_frame, text="Description:", font=('Arial', 14)).grid(row=2, column=0, padx=10, pady=10)
        self.description_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.description_entry.grid(row=2, column=1, padx=10, pady=10)

        tk.Label(form_frame, text="Prep Time (minutes):", font=('Arial', 14)).grid(row=3, column=0, padx=10, pady=10)
        self.prep_time_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.prep_time_entry.grid(row=3, column=1, padx=10, pady=10)

        tk.Label(form_frame, text="Cook Time (minutes):", font=('Arial', 14)).grid(row=4, column=0, padx=10, pady=10)
        self.cook_time_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.cook_time_entry.grid(row=4, column=1, padx=10, pady=10)

        button_frame = tk.Frame(form_frame)
        button_frame.grid(row=5, column=0, columnspan=2, pady=20)

        add_button = tk.Button(button_frame, text="Add Recipe", font=('Arial', 14), command=self.add_recipe)
        add_button.pack(side=tk.LEFT, padx=10)

        cancel_button = tk.Button(button_frame, text="Cancel", font=('Arial', 14), command=self.show_menus)
        cancel_button.pack(side=tk.LEFT, padx=10)

    def show_recipe_form_for_editing(self, recipe):
        for widget in self.container.winfo_children():
            widget.destroy()

        form_frame = tk.Frame(self.container)
        form_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER)

        tk.Label(form_frame, text="Title:", font=('Arial', 14)).grid(row=0, column=0, padx=10, pady=10)
        self.title_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.title_entry.insert(0, recipe[1])
        self.title_entry.grid(row=0, column=1, padx=10, pady=10)

        tk.Label(form_frame, text="Author:", font=('Arial', 14)).grid(row=1, column=0, padx=10, pady=10)
        self.author_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.author_entry.insert(0, recipe[2])
        self.author_entry.grid(row=1, column=1, padx=10, pady=10)

        tk.Label(form_frame, text="Description:", font=('Arial', 14)).grid(row=2, column=0, padx=10, pady=10)
        self.description_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.description_entry.insert(0, recipe[3])
        self.description_entry.grid(row=2, column=1, padx=10, pady=10)

        tk.Label(form_frame, text="Prep Time (minutes):", font=('Arial', 14)).grid(row=3, column=0, padx=10, pady=10)
        self.prep_time_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.prep_time_entry.insert(0, recipe[4])
        self.prep_time_entry.grid(row=3, column=1, padx=10, pady=10)

        tk.Label(form_frame, text="Cook Time (minutes):", font=('Arial', 14)).grid(row=4, column=0, padx=10, pady=10)
        self.cook_time_entry = tk.Entry(form_frame, font=('Arial', 14))
        self.cook_time_entry.insert(0, recipe[5])
        self.cook_time_entry.grid(row=4, column=1, padx=10, pady=10)

        button_frame = tk.Frame(form_frame)
        button_frame.grid(row=5, column=0, columnspan=2, pady=20)

        save_button = tk.Button(button_frame, text="Save Changes", font=('Arial', 14), command=lambda: self.save_recipe_changes(recipe[0]))
        save_button.pack(side=tk.LEFT, padx=10)

        cancel_button = tk.Button(button_frame, text="Cancel", font=('Arial', 14), command=self.show_menus)
        cancel_button.pack(side=tk.LEFT, padx=10)

    def view_recipe(self, recipe):
        # Clear the existing content
        for widget in self.container.winfo_children():
            widget.destroy()

        # Display recipe details in larger format
        form_frame = tk.Frame(self.container)
        form_frame.place(relx=0.5, rely=0.5, anchor=tk.CENTER)

        tk.Label(form_frame, text=f"Title: {recipe[1]}", font=('Arial', 20)).pack(pady=10)
        tk.Label(form_frame, text=f"Author: {recipe[2]}", font=('Arial', 20)).pack(pady=10)
        tk.Label(form_frame, text=f"Description: {recipe[3]}", font=('Arial', 20), wraplength=400).pack(pady=10)
        tk.Label(form_frame, text=f"Prep Time: {recipe[4]} mins", font=('Arial', 20)).pack(pady=10)
        tk.Label(form_frame, text=f"Cook Time: {recipe[5]} mins", font=('Arial', 20)).pack(pady=10)

        back_button = tk.Button(form_frame, text="Back to Menus", font=('Arial', 16), command=self.show_menus)
        back_button.pack(pady=20)

    def save_recipe_changes(self, recipe_id):
        # Get the data from the form entries
        title = self.title_entry.get()
        author = self.author_entry.get()
        description = self.description_entry.get()
        prep_time = self.prep_time_entry.get()
        cook_time = self.cook_time_entry.get()

        # Validate the inputs
        if not title or not author or not prep_time or not cook_time:
            messagebox.showerror("Input Error", "All fields must be filled out.")
            return
        try:
            prep_time = int(prep_time)  # Ensure prep time is an integer
            cook_time = int(cook_time)  # Ensure cook time is an integer
        except ValueError:
            messagebox.showerror("Input Error", "Prep Time and Cook Time must be integers.")
            return

        # Update the recipe in the database
        cursor.execute("""
            UPDATE recipes
            SET title = ?, author = ?, description = ?, prep_time = ?, cook_time = ?
            WHERE id = ?
        """, (title, author, description, prep_time, cook_time, recipe_id))
        conn.commit()

        # Show a success message
        messagebox.showinfo("Success", "Recipe updated successfully!")

        # Return to the recipes list
        self.show_menus()

    def add_scrollbar_to_frame(self, frame):
        # Create a canvas to hold the frame
        canvas = tk.Canvas(frame)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # Add a scrollbar to the canvas
        scrollbar = tk.Scrollbar(frame, command=canvas.yview)
        scrollbar.pack(side=tk.RIGHT, fill="y")

        # Configure the canvas
        canvas.configure(yscrollcommand=scrollbar.set)

        # Create a frame inside the canvas to hold the items or menus
        content_frame = tk.Frame(canvas)
        canvas.create_window((0, 0), window=content_frame, anchor="nw")

        # Update scrollregion when content changes
        content_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))

        # Store canvas reference
        self.canvas = canvas

        # Bind touch scroll events to the canvas and all child widgets
        self.bind_scroll_events(content_frame)

        return content_frame

    def bind_scroll_events(self, widget):
        widget.bind("<Button-1>", self.on_touch_start, add="+")
        widget.bind("<B1-Motion>", self.on_touch_scroll, add="+")
        for child in widget.winfo_children():
            self.bind_scroll_events(child)

    def on_touch_start(self, event):
        print("Touch start")
        self.last_y = event.y

    def on_touch_scroll(self, event):
        print("Touch scroll")
        delta_y = self.last_y - event.y
        self.last_y = event.y
        scroll_amount = int(delta_y / 5)
        self.canvas.yview_scroll(scroll_amount, "units")

    def show_grocery(self):
        # Clear existing content
        for widget in self.container.winfo_children():
            widget.destroy()

        # Main title
        title = tk.Label(self.container, text="Grocery List", font=('Arial', 24))
        title.pack(pady=20)

        # Top controls frame (input and back button)
        top_frame = tk.Frame(self.container)
        top_frame.pack(fill=tk.X, padx=20, pady=10)

        # Input area
        input_frame = tk.Frame(top_frame)
        input_frame.pack(side=tk.LEFT, expand=True, fill=tk.X)

        self.grocery_entry = tk.Entry(input_frame, font=('Arial', 14))
        self.grocery_entry.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(0, 10))

        add_btn = tk.Button(input_frame, text="Add Item", font=('Arial', 14),
                           command=self.add_grocery_item)
        add_btn.pack(side=tk.LEFT)

        # Back button in top frame
        back_btn = tk.Button(top_frame, text="Back to Main Menu",
                           font=('Arial', 16), command=self.show_main_menu)
        back_btn.pack(side=tk.RIGHT, padx=10)

        # Search and filter frame
        search_frame = tk.Frame(self.container)
        search_frame.pack(fill=tk.X, padx=20, pady=10)

        # Search bar
        search_label = tk.Label(search_frame, text="Search:", font=('Arial', 14))
        search_label.pack(side=tk.LEFT, padx=(0, 5))

        self.grocery_search = tk.Entry(search_frame, font=('Arial', 14))
        self.grocery_search.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(0, 10))
        
        # Filter dropdown
        filter_label = tk.Label(search_frame, text="Sort by:", font=('Arial', 14))
        filter_label.pack(side=tk.LEFT, padx=(10, 5))

        self.filter_var = tk.StringVar(value="A to Z")
        filter_options = [
            "Unchecked",
            "A to Z",
            "Z to A",
            "First added",
            "Last added"
        ]
        filter_menu = ttk.Combobox(search_frame, 
                                  textvariable=self.filter_var,
                                  values=filter_options,
                                  state='readonly',
                                  font=('Arial', 14))
        filter_menu.pack(side=tk.LEFT, padx=5)

        self.grocery_search.bind('<KeyRelease>', lambda e: self.filter_grocery_items())
        filter_menu.bind('<<ComboboxSelected>>', lambda e: self.filter_grocery_items())

        # Add scrollable frame for grocery list
        scrollable_frame = tk.Frame(self.container)
        scrollable_frame.pack(fill=tk.BOTH, expand=True)
        self.grocery_list = self.add_scrollbar_to_frame(scrollable_frame)

        # Initialize the filter to show all items
        self.filter_grocery_items()

    def filter_grocery_items(self):
        """Filter and sort grocery items based on search text and selected filter."""
        search_text = self.grocery_search.get().lower()
        filter_option = self.filter_var.get()

        # Get all items from database
        if filter_option == "Unchecked":
            cursor.execute("""
                SELECT * FROM grocery_items 
                ORDER BY checked ASC, name ASC
            """)
        elif filter_option == "A to Z":
            cursor.execute("SELECT * FROM grocery_items ORDER BY name ASC")
        elif filter_option == "Z to A":
            cursor.execute("SELECT * FROM grocery_items ORDER BY name DESC")
        elif filter_option == "First added":
            cursor.execute("SELECT * FROM grocery_items ORDER BY created_at ASC")
        else:  # Last added
            cursor.execute("SELECT * FROM grocery_items ORDER BY created_at DESC")

        items = cursor.fetchall()

        # Filter based on search text
        if search_text:
            items = [item for item in items if search_text in item[1].lower()]

        # Clear existing items
        for widget in self.grocery_list.winfo_children():
            widget.destroy()

        # Store references to labels
        self.item_labels = {}

        # Create items
        for item in items:
            # Create frame for each item
            item_frame = tk.Frame(self.grocery_list)
            item_frame.pack(fill=tk.X, pady=5, padx=10)

            # Checkbox
            var = tk.BooleanVar(value=bool(item[2]))
            check = tk.Checkbutton(item_frame, variable=var,
                                 command=lambda i=item[0], v=var: 
                                 self.toggle_grocery_item_display(i, v))
            check.pack(side=tk.LEFT)

            # Item text - green if checked, black if not
            text = tk.Label(item_frame, text=item[1], font=('Arial', 14),
                          fg='green' if item[2] else 'black')
            text.pack(side=tk.LEFT, padx=5)
            
            # Store reference to the label
            self.item_labels[item[0]] = text

            # Delete button
            delete = tk.Button(item_frame, text="×", font=('Arial', 14),
                             command=lambda i=item[0]: self.delete_grocery_item(i))
            delete.pack(side=tk.RIGHT, padx=5)

    def toggle_grocery_item_display(self, item_id, var):
        # Update database
        checked = 1 if var.get() else 0
        cursor.execute("UPDATE grocery_items SET checked = ? WHERE id = ?",
                      (checked, item_id))
        conn.commit()

        # Update label color without rebuilding the list
        label = self.item_labels[item_id]
        label.configure(fg='green' if var.get() else 'black')

    def delete_grocery_item(self, item_id):
        cursor.execute("DELETE FROM grocery_items WHERE id = ?", (item_id,))
        conn.commit()
        self.filter_grocery_items()

    def add_grocery_item(self):
        name = self.grocery_entry.get().strip()
        if name:
            cursor.execute("""
                INSERT INTO grocery_items (name, checked, created_at)
                VALUES (?, 0, ?)
            """, (name, datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
            conn.commit()
            self.grocery_entry.delete(0, tk.END)
            self.populate_grocery_items()

    def shutdown(self):
        os.system("sudo shutdown now")

    def restart(self):
        os.system("sudo reboot")

    def sleep(self):
        """Turn off the official Raspberry Pi touchscreen display."""
        try:
            # First try to find the correct backlight directory
            backlight_dirs = os.listdir('/sys/class/backlight/')
            if not backlight_dirs:
                raise Exception("No backlight control found")
            
            backlight_dir = backlight_dirs[0]  # Use the first (and usually only) backlight directory
            bl_power_path = f"/sys/class/backlight/{backlight_dir}/bl_power"
            
            # Turn off the backlight power (1 = off, 0 = on)
            os.system(f"sudo sh -c 'echo 1 > {bl_power_path}'")
            
            # Bind screen tap event to wake up
            self.bind("<Button-1>", lambda e: self.wake_up())
            # Bind keyboard event to wake up
            self.bind("<Key>", lambda e: self.wake_up())
            
        except Exception as e:
            print(f"Failed to turn off display: {e}")
            messagebox.showerror("Error", f"Failed to turn off display: {e}")

    def wake_up(self):
        """Turn the display back on and return to main menu."""
        try:
            # Find the backlight directory again
            backlight_dirs = os.listdir('/sys/class/backlight/')
            if backlight_dirs:
                backlight_dir = backlight_dirs[0]
                bl_power_path = f"/sys/class/backlight/{backlight_dir}/bl_power"
                
                # Turn the backlight power back on (0 = on)
                os.system(f"sudo sh -c 'echo 0 > {bl_power_path}'")
            
            # Unbind the wake-up events
            self.unbind("<Button-1>")
            self.unbind("<Key>")
            
            # Return to main menu
            self.show_main_menu()
            
        except Exception as e:
            print(f"Failed to wake up display: {e}")
            messagebox.showerror("Error", f"Failed to wake up display: {e}")

if __name__ == "__main__":
    app = FridgeManagerApp()
    app.mainloop()
