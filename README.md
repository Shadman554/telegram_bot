# Veterinary Dictionary Telegram Bot

A standalone Telegram bot that provides complete admin functionality for managing veterinary dictionary content.

## Features

- **Complete CRUD Operations**: Create, Read, Update, Delete for all collections
- **11 Collections Supported**: Books, Dictionary, Diseases, Drugs, Videos, Staff, Questions, Notifications, Users, Normal Ranges, App Links
- **Interactive Interface**: Easy-to-use inline keyboards
- **Session Management**: Tracks user state across conversations
- **Error Handling**: Graceful error handling with user-friendly messages

## Quick Start

1. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Setup Environment**:
   ```bash
   cp .env.example .env
   # Edit .env and add your TELEGRAM_BOT_TOKEN
   ```

3. **Run the Bot**:
   ```bash
   python run.py
   ```

## Getting Bot Token

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Send `/newbot` command
3. Follow prompts to create your bot
4. Copy the token and add it to `.env` file

## Available Commands

- `/start` - Start the bot and show main menu
- `/help` - Show help message
- `/menu` - Show main menu
- `/stats` - View statistics
- `/collections` - List all collections

## Collections & Fields

### 📚 Books
- title, description, category, coverImageUrl, pdfUrl

### 📖 Dictionary
- name, kurdish, arabic, description

### 🦠 Diseases
- name, kurdish, symptoms, cause, control

### 💊 Drugs
- name, usage, sideEffect, otherInfo, class

### 🎥 Tutorial Videos
- Title, VideoID

### 👥 Staff
- name, job, description, photo, facebook, instagram, snapchat, twitter

### ❓ Questions
- text, userName, userEmail, likes

### 📱 Notifications
- title, body, imageUrl

### 👤 Users
- username, today_points, total_points

### 📊 Normal Ranges
- name, unit, minValue, maxValue, species, category

### 🔗 App Links
- url

## Usage Examples

### Adding Content
1. Send `/start`
2. Click "➕ Add Content"
3. Choose collection (e.g., "📚 Books")
4. Follow prompts to enter each field
5. Bot saves and confirms

### Viewing Content
1. Send `/start`
2. Click "👁️ View Content"
3. Choose collection to view
4. See list of items with IDs

### Editing Content
1. Send `/start`
2. Click "✏️ Edit Content"
3. Choose collection
4. Provide item ID
5. Enter new values for each field

## Data Storage

Currently uses in-memory storage for demonstration. Can be extended to use:
- Firebase (configuration ready)
- PostgreSQL
- MongoDB
- Any other database

## Project Structure

```
telegram-bot/
├── bot.py              # Main bot implementation
├── run.py              # Bot runner script
├── requirements.txt    # Python dependencies
├── .env.example        # Environment variables template
└── README.md          # This file
```

## Development

To extend the bot:
1. Modify collections in `bot.py`
2. Add new handlers for additional functionality
3. Update field configurations as needed

## License

MIT License