# Inventory App

Flutter app with Firestore real-time inventory management. Add, edit, delete items instantly.

## Enhanced Features

1. **Search** - Filter items by name or description in real-time
2. **Sort** - Toggle sorting by item name or quantity

## How It Works

- **StreamBuilder** listens to Firestore for real-time updates
- **Item model** with `toMap()`/`fromMap()` for serialization  
- **FirestoreService** handles CRUD (add, update, delete, stream)
- **Forms** validate empty fields and numeric values
- **Loading states** show spinners while saving

## Usage

- **Add:** Tap `+` → Fill form → Tap "Add"
- **Edit:** Tap item menu → "Edit" → Update → "Update"
- **Delete:** Tap item menu → "Delete"
- **Search:** Type in search box to filter items
- **Sort:** Tap "Sort" to toggle between name and quantity sorting