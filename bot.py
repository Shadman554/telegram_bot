#!/usr/bin/env python3
"""
Veterinary Dictionary Telegram Bot
Complete standalone admin bot for managing veterinary content
"""

import logging
import os
import json
from typing import Dict, Any
from datetime import datetime

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
from dotenv import load_dotenv
from firebase_admin import credentials, firestore, initialize_app

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

class VetDictionaryBot:
    def __init__(self):
        # Check for existing instance
        self.lock_file = os.path.join(os.path.dirname(__file__), 'bot.lock')
        if os.path.exists(self.lock_file):
            raise RuntimeError("Another bot instance is already running")
        open(self.lock_file, 'w').close()
        
        self.bot_token = os.getenv('TELEGRAM_BOT_TOKEN')
        if not self.bot_token:
            raise ValueError("TELEGRAM_BOT_TOKEN environment variable is required")
        
        # User sessions for maintaining state
        self.user_sessions: Dict[int, Dict[str, Any]] = {}

        # Initialize Firebase (Firestore)
        self.db = self._init_firebase()
        
        # Collection configurations
        self.collections = {
            'books': {
                'name': 'Books',
                'emoji': '📚',
                'fields': ['title', 'description', 'category', 'coverImageUrl', 'pdfUrl'],
                'description': 'Manage veterinary books and publications'
            },
            'words': {
                'name': 'Dictionary',
                'emoji': '📖',
                'fields': ['name', 'kurdish', 'arabic', 'description'],
                'description': 'Manage veterinary dictionary terms'
            },
            'diseases': {
                'name': 'Diseases',
                'emoji': '🦠',
                'fields': ['name', 'kurdish', 'symptoms', 'cause', 'control'],
                'description': 'Manage animal diseases and conditions'
            },
            'drugs': {
                'name': 'Drugs',
                'emoji': '💊',
                'fields': ['name', 'usage', 'sideEffect', 'otherInfo', 'class'],
                'description': 'Manage veterinary medications'
            },
            'tutorialVideos': {
                'name': 'Tutorial Videos',
                'emoji': '🎥',
                'fields': ['Title', 'VideoID'],
                'description': 'Manage educational videos'
            },
            'staff': {
                'name': 'Staff',
                'emoji': '👥',
                'fields': ['name', 'job', 'description', 'photo', 'facebook', 'instagram', 'snapchat', 'twitter'],
                'description': 'Manage staff members'
            },
            'questions': {
                'name': 'Questions',
                'emoji': '❓',
                'fields': ['text', 'userName', 'userEmail', 'likes'],
                'description': 'Manage user questions'
            },
            'notifications': {
                'name': 'Notifications',
                'emoji': '📱',
                'fields': ['title', 'body', 'imageUrl'],
                'description': 'Manage system notifications'
            },
            'users': {
                'name': 'Users',
                'emoji': '👤',
                'fields': ['username', 'today_points', 'total_points'],
                'description': 'Manage application users'
            },
            'normalRanges': {
                'name': 'Normal Ranges',
                'emoji': '📊',
                'fields': ['name', 'unit', 'minValue', 'maxValue', 'species', 'category'],
                'description': 'Manage normal reference ranges'
            },
            'appLinks': {
                'name': 'App Links',
                'emoji': '🔗',
                'fields': ['url'],
                'description': 'Manage application download links'
            }
        }

    def __del__(self):
        # Cleanup lock file
        if hasattr(self, 'lock_file') and os.path.exists(self.lock_file):
            os.remove(self.lock_file)

    def _init_firebase(self):
        """Initialize Firebase Firestore client from serviceAccount.json file.
        Returns the Firestore client instance or None if credentials are missing/invalid.
        """
        # Use the serviceAccount.json file directly
        sa_path = os.path.join(os.path.dirname(__file__), 'serviceAccount.json')
        
        if os.path.isfile(sa_path):
            try:
                # Read and validate the service account file
                with open(sa_path, 'r') as f:
                    sa_data = json.load(f)
                
                # Validate required fields
                required_fields = ['type', 'project_id', 'private_key', 'client_email']
                if not all(field in sa_data for field in required_fields):
                    logger.error("Service account file is missing required fields")
                    return None
                
                # Clean up the private key
                private_key = sa_data['private_key']
                if not private_key.startswith('-----BEGIN PRIVATE KEY-----'):
                    logger.error("Invalid private key format")
                    return None
                
                cred = credentials.Certificate(sa_path)
                try:
                    initialize_app(cred)
                except ValueError:
                    pass  # already initialised
                logger.info("Firebase initialised from serviceAccount.json file.")
                return firestore.client()
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON in service account file: {e}")
                return None
            except Exception as e:
                logger.error(f"Failed to init Firebase using serviceAccount.json: {e}")
                return None
        
        # Fallback to environment variables
        project_id = os.getenv("FIREBASE_PROJECT_ID")
        private_key = os.getenv("FIREBASE_PRIVATE_KEY")
        client_email = os.getenv("FIREBASE_CLIENT_EMAIL")

        # Validate required credentials
        if not (project_id and private_key and client_email):
            logger.warning("Firebase credentials are incomplete; skipping Firebase integration.")
            return None

        try:
            # Clean and validate private key
            cleaned_key = private_key.replace('\\n', '\n').strip('"').strip("'")
            if not cleaned_key.startswith('-----BEGIN PRIVATE KEY-----'):
                logger.error("Invalid private key format in environment variables")
                return None
            
            cred = credentials.Certificate({
                "type": "service_account",
                "project_id": project_id,
                "private_key": cleaned_key,
                "client_email": client_email,
                "token_uri": "https://oauth2.googleapis.com/token"
            })
            # Initialize the Firebase app only once
            try:
                initialize_app(cred)
            except ValueError:
                # Firebase already initialized by another part of the program
                pass
            return firestore.client()
        except Exception as e:
            logger.error(f"Failed to initialize Firebase: {e}")
            return None

    def get_session(self, user_id: int) -> Dict[str, Any]:
        if user_id not in self.user_sessions:
            self.user_sessions[user_id] = {}
        return self.user_sessions[user_id]

    def clear_session(self, user_id: int):
        if user_id in self.user_sessions:
            self.user_sessions[user_id] = {}

    async def start_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        user_id = update.effective_user.id
        self.clear_session(user_id)
        
        welcome_text = (
            "🐾 Welcome to Veterinary Dictionary Admin Bot!\n\n"
            "This bot provides the same functionality as the website:\n"
            "📚 Books, 📖 Dictionary, 🦠 Diseases, 💊 Drugs\n"
            "🎥 Videos, 👥 Staff, ❓ Questions, 📱 Notifications\n"
            "👤 Users, 📊 Normal Ranges, 🔗 App Links\n\n"
            "All collections and fields match the website exactly!"
        )
        
        await update.message.reply_text(
            welcome_text,
            reply_markup=self.get_main_menu_keyboard()
        )

    async def help_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        help_text = (
            "📋 Available Commands:\n\n"
            "/start - Start the bot\n"
            "/menu - Show main menu\n"
            "/stats - View statistics\n"
            "/collections - List all collections\n"
            "/help - Show this help message"
        )
        await update.message.reply_text(help_text)

    async def menu_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        await update.message.reply_text(
            "Select an option:",
            reply_markup=self.get_main_menu_keyboard()
        )

    async def collections_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        collections_text = "📋 Available Collections:\n\n"
        for key, info in self.collections.items():
            count = self.get_collection_count(key)
            collections_text += f"{info['emoji']} {info['name']} ({count} items)\n"
            collections_text += f"   {info['description']}\n\n"
        
        await update.message.reply_text(collections_text)

    async def stats_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        await self.show_statistics(update)

    def get_main_menu_keyboard(self) -> InlineKeyboardMarkup:
        keyboard = [
            [InlineKeyboardButton("➕ Add Content", callback_data="menu_add")],
            [InlineKeyboardButton("👁️ View Content", callback_data="menu_view")],
            [InlineKeyboardButton("🔍 Search Content", callback_data="menu_search")],
            [InlineKeyboardButton("✏️ Edit Content", callback_data="menu_edit")],
            [InlineKeyboardButton("🗑️ Delete Content", callback_data="menu_delete")],
            [InlineKeyboardButton("📊 Statistics", callback_data="menu_stats")],
            [InlineKeyboardButton("📋 Collections Info", callback_data="menu_collections")]
        ]
        return InlineKeyboardMarkup(keyboard)

    def get_collection_menu_keyboard(self, action: str) -> InlineKeyboardMarkup:
        keyboard = []
        row = []
        
        for i, (collection_key, collection_info) in enumerate(self.collections.items()):
            button = InlineKeyboardButton(
                f"{collection_info['emoji']} {collection_info['name']}",
                callback_data=f"{action}_{collection_key}"
            )
            row.append(button)
            
            if len(row) == 2 or i == len(self.collections) - 1:
                keyboard.append(row)
                row = []
        
        keyboard.append([InlineKeyboardButton("« Back to Menu", callback_data="back_to_menu")])
        return InlineKeyboardMarkup(keyboard)

    def get_back_to_menu_keyboard(self) -> InlineKeyboardMarkup:
        keyboard = [[InlineKeyboardButton("« Back to Menu", callback_data="back_to_menu")]]
        return InlineKeyboardMarkup(keyboard)

    async def handle_callback_query(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        query = update.callback_query
        data = query.data
        
        try:
            await query.answer()
            
            # === Main menu buttons ===
            if data == "back_to_menu":
                await query.edit_message_text(
                    "Select an option:",
                    reply_markup=self.get_main_menu_keyboard()
                )
            elif data == "menu_add":
                await query.edit_message_text(
                    "Select a collection to add:",
                    reply_markup=self.get_collection_menu_keyboard("add")
                )
            elif data == "menu_view":
                await query.edit_message_text(
                    "Select a collection to view:",
                    reply_markup=self.get_collection_menu_keyboard("view")
                )
            elif data == "menu_edit":
                await query.edit_message_text(
                    "Select a collection to edit:",
                    reply_markup=self.get_collection_menu_keyboard("edit")
                )
            elif data == "menu_delete":
                await query.edit_message_text(
                    "Select a collection to delete:",
                    reply_markup=self.get_collection_menu_keyboard("delete")
                )
            elif data == "menu_search":
                await query.edit_message_text(
                    "Select a collection to search:",
                    reply_markup=self.get_collection_menu_keyboard("search")
                )
            elif data == "menu_stats":
                await self.show_statistics_callback(query)
            elif data == "menu_collections":
                await self.show_collections_info_callback(query)
            # === Collection-specific actions (e.g. add_books) ===
            elif data.startswith(("add_", "view_", "edit_", "delete_", "search_")):
                await self.handle_collection_action(query, data)
            else:
                logger.warning(f"Unknown button action received: {data}")
                if update.effective_message:
                    await update.effective_message.reply_text(
                        f"⚠️ Unknown action: {data.split('_')[0] if '_' in data else data}\n\nPlease use the menu buttons",
                        reply_markup=self.get_back_to_menu_keyboard()
                    )
                else:
                    logger.warning("No effective message to reply to. Sending default message.")
                    if update.effective_chat:
                        await update.effective_chat.send_message(
                            "⚠️ Action could not be completed. Please try again from the menu.",
                            reply_markup=self.get_main_menu_keyboard()
                        )
                
        except Exception as e:
            logger.error(f"Error in callback handler: {e}")
            if update.effective_chat:
                await update.effective_chat.send_message(
                    "An error occurred. Please use /start to restart.",
                    reply_markup=self.get_main_menu_keyboard()
                )

    async def show_collections_info_callback(self, query):
        collections_text = "📋 Available Collections:\n\n"
        for key, info in self.collections.items():
            count = self.get_collection_count(key)
            collections_text += f"{info['emoji']} {info['name']} ({count} items)\n"
            collections_text += f"   {info['description']}\n"
            collections_text += f"   Fields: {', '.join(info['fields'])}\n\n"
        
        await query.edit_message_text(
            collections_text,
            reply_markup=self.get_back_to_menu_keyboard()
        )

    async def handle_collection_action(self, query, data: str):
        parts = data.split("_", 1)
        action = parts[0]
        collection = parts[1]
        user_id = query.from_user.id
        session = self.get_session(user_id)
        
        try:
            if action == "add":
                session['action'] = 'add'
                session['collection'] = collection
                session['current_field'] = 0
                session['data'] = {}
                
                collection_info = self.collections[collection]
                field = collection_info['fields'][0]
                
                await query.edit_message_text(
                    f"Adding new {collection_info['name']}.\n\n"
                    f"Fields to fill: {', '.join(collection_info['fields'])}\n\n"
                    f"Please send me the {field}:"
                )
                
            elif action == "view":
                await self.show_collection_data(query, collection)
                
            elif action == "edit":
                session['action'] = 'edit'
                session['collection'] = collection
                session['waiting_for'] = 'id'
                
                collection_info = self.collections[collection]
                await query.edit_message_text(
                    f"Please send me the ID of the {collection_info['name'].lower()} you want to edit:"
                )
                
            elif action == "delete":
                session['action'] = 'delete'
                session['collection'] = collection
                session['waiting_for'] = 'id'
                
                collection_info = self.collections[collection]
                await query.edit_message_text(
                    f"Please send me the ID of the {collection_info['name'].lower()} you want to delete:"
                )
                
            elif action == "search":
                session['action'] = 'search'
                session['collection'] = collection
                session['waiting_for'] = 'search_query'
                
                collection_info = self.collections[collection]
                await query.edit_message_text(
                    f"🔍 Search in {collection_info['name']}\n\n"
                    f"Please send me the search term:"
                )
        except Exception as e:
            logger.error(f"Error in collection action: {e}")
            await query.message.reply_text(
                "An error occurred. Please use /start to restart.",
                reply_markup=self.get_main_menu_keyboard()
            )

    async def handle_text_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        user_id = update.effective_user.id
        session = self.get_session(user_id)
        text = update.message.text
        
        if not session.get('action'):
            await update.message.reply_text(
                "Please use /start to get the menu first!",
                reply_markup=self.get_main_menu_keyboard()
            )
            return
        
        try:
            if session['action'] == 'add':
                await self.handle_add_input(update, text, session)
            elif session['action'] == 'edit':
                await self.handle_edit_input(update, text, session)
            elif session['action'] == 'delete':
                await self.handle_delete_input(update, text, session)
            elif session['action'] == 'search':
                await self.handle_search_input(update, text, session)
        except Exception as e:
            logger.error(f"Error handling text message: {e}")
            await update.message.reply_text(
                "An error occurred. Please use /start to restart.",
                reply_markup=self.get_main_menu_keyboard()
            )

    async def handle_add_input(self, update: Update, text: str, session: Dict[str, Any]):
        collection = session['collection']
        collection_info = self.collections[collection]
        fields = collection_info['fields']
        current_field_index = session['current_field']
        
        field_name = fields[current_field_index]
        session['data'][field_name] = text
        
        if current_field_index + 1 < len(fields):
            session['current_field'] += 1
            next_field = fields[current_field_index + 1]
            remaining = len(fields) - current_field_index - 1
            
            await update.message.reply_text(
                f"✅ {field_name}: {text}\n\n"
                f"Now send me the {next_field}:\n"
                f"({remaining} fields remaining)"
            )
        else:
            await self.save_new_item(update, session)

    async def save_new_item(self, update: Update, session: Dict[str, Any]):
        collection = session['collection']
        data = session['data']
        collection_info = self.collections[collection]
        
        if not self.db:
            await update.message.reply_text(
                "❌ Firebase not initialized. Cannot save data.",
                reply_markup=self.get_main_menu_keyboard()
            )
            return
            
        try:
            # Validate required fields based on collection type
            validation_error = self.validate_item_data(collection, data)
            if validation_error:
                await update.message.reply_text(
                    f"❌ Validation error: {validation_error}",
                    reply_markup=self.get_main_menu_keyboard()
                )
                return
            
            # Generate timestamp-based numeric ID for the id field (matching your existing structure)
            import time
            numeric_id = int(time.time() * 1000)  # Current timestamp in milliseconds
            data['id'] = numeric_id
            data['createdAt'] = datetime.now().isoformat()
            
            # Add collection-specific fields if needed
            if collection == 'drugs':
                data['class'] = data.get('class', 'General')  # Default class for drugs
            elif collection == 'normalRanges':
                # Ensure numeric values for ranges
                data['minValue'] = float(data.get('minValue', 0))
                data['maxValue'] = float(data.get('maxValue', 0))
            
            # Let Firebase auto-generate the document ID (matching your existing pattern)
            doc_ref = self.db.collection(collection).add(data)
            generated_doc_id = doc_ref[1].id  # Get the auto-generated document ID
            logger.info(f"Saved new {collection} item to Firebase with document ID {generated_doc_id} and numeric ID {numeric_id}")
            
            data_display = "\n".join([f"• {key}: {value}" for key, value in data.items() if key not in ['id', 'createdAt']])
            
            await update.message.reply_text(
                f"✅ {collection_info['name']} added to Firebase!\n\n"
                f"Document ID: {generated_doc_id}\n"
                f"Numeric ID: {numeric_id}\n"
                f"{data_display}",
                reply_markup=self.get_main_menu_keyboard()
            )
            
            self.clear_session(update.effective_user.id)
            
        except Exception as e:
            logger.error(f"🔥 Firestore save failed: {str(e)}", exc_info=True)
            await update.message.reply_text(
                f"❌ Firestore error: {str(e)}",
                reply_markup=self.get_main_menu_keyboard()
            )

    def validate_item_data(self, collection: str, data: dict) -> str:
        """Validate item data based on collection requirements"""
        required_fields = {
            'words': ['name', 'kurdish', 'arabic'],
            'drugs': ['name', 'usage'],
            'books': ['title', 'description'],
            'diseases': ['name', 'symptoms'],
            'staff': ['name', 'job'],
            'tutorialVideos': ['Title', 'VideoID'],
            'notifications': ['title', 'body'],
            'users': ['username'],
            'normalRanges': ['name', 'unit', 'minValue', 'maxValue'],
            'appLinks': ['url']
        }
        
        if collection in required_fields:
            for field in required_fields[collection]:
                if not data.get(field, '').strip():
                    return f"Field '{field}' is required and cannot be empty"
        
        # Special validations
        if collection == 'normalRanges':
            try:
                min_val = float(data.get('minValue', 0))
                max_val = float(data.get('maxValue', 0))
                if min_val >= max_val:
                    return "minValue must be less than maxValue"
            except ValueError:
                return "minValue and maxValue must be valid numbers"
        
        return None  # No validation errors

    async def handle_edit_input(self, update: Update, text: str, session: Dict[str, Any]):
        if session.get('waiting_for') == 'id':
            try:
                item_id = int(text)
                collection = session['collection']
                
                # Search for document by the numeric ID field (not document ID)
                docs = self.db.collection(collection).where('id', '==', item_id).stream()
                doc_found = None
                doc_id = None
                
                for doc in docs:
                    doc_found = doc
                    doc_id = doc.id
                    break
                
                if doc_found:
                    session['item_id'] = item_id
                    session['doc_id'] = doc_id  # Store the Firebase document ID
                    session['waiting_for'] = 'field_data'
                    session['current_field'] = 0
                    session['data'] = {}
                    
                    collection_info = self.collections[collection]
                    field = collection_info['fields'][0]
                    
                    current_data = "\n".join([f"• {key}: {value}" for key, value in doc_found.to_dict().items() if key not in ['id', 'createdAt']])
                    
                    await update.message.reply_text(
                        f"Editing {collection_info['name']} (ID: {item_id})\n\n"
                        f"Current data:\n{current_data}\n\n"
                        f"Please send me the new {field}:"
                    )
                else:
                    await update.message.reply_text(
                        f"❌ Item with ID {item_id} not found.",
                        reply_markup=self.get_main_menu_keyboard()
                    )
                    self.clear_session(update.effective_user.id)
            except ValueError:
                await update.message.reply_text("❌ Please provide a valid numeric ID.")
        else:
            await self.handle_add_input(update, text, session)

    async def handle_delete_input(self, update: Update, text: str, session: Dict[str, Any]):
        if session.get('waiting_for') == 'id':
            try:
                item_id = int(text)
                collection = session['collection']
                collection_info = self.collections[collection]
                
                # Search for document by the numeric ID field (not document ID)
                docs = self.db.collection(collection).where('id', '==', item_id).stream()
                doc_found = None
                
                for doc in docs:
                    doc_found = doc
                    break
                
                if doc_found:
                    doc_found.reference.delete()
                    await update.message.reply_text(
                        f"✅ {collection_info['name']} with ID {item_id} deleted successfully!",
                        reply_markup=self.get_main_menu_keyboard()
                    )
                else:
                    await update.message.reply_text(
                        f"❌ Item with ID {item_id} not found.",
                        reply_markup=self.get_main_menu_keyboard()
                    )
                
                self.clear_session(update.effective_user.id)
                
            except ValueError:
                await update.message.reply_text("❌ Please provide a valid numeric ID.")

    async def handle_search_input(self, update: Update, text: str, session: Dict[str, Any]):
        if session.get('waiting_for') == 'search_query':
            try:
                search_term = text.strip()
                collection = session['collection']
                collection_info = self.collections[collection]
                
                # Search logic based on collection type
                results = await self.search_in_collection(collection, search_term)
                
                if results:
                    search_text = f"🔍 Search results for '{search_term}' in {collection_info['name']}:\n\n"
                    
                    for item in results[:10]:  # Limit to 10 results
                        display_name = self.get_item_display_name(item, collection)
                        search_text += f"• {display_name} (ID: {item.get('id', 'N/A')})\n"
                    
                    if len(results) > 10:
                        search_text += f"\n... and {len(results) - 10} more results"
                    
                    search_text += f"\n\nTotal found: {len(results)} items"
                else:
                    search_text = f"❌ No results found for '{search_term}' in {collection_info['name']}"
                
                await update.message.reply_text(
                    search_text,
                    reply_markup=self.get_main_menu_keyboard()
                )
                
                self.clear_session(update.effective_user.id)
                
            except Exception as e:
                logger.error(f"Error in search: {e}")
                await update.message.reply_text(
                    f"❌ Search error: {str(e)}",
                    reply_markup=self.get_main_menu_keyboard()
                )
                self.clear_session(update.effective_user.id)

    async def show_collection_data(self, query, collection: str):
        collection_info = self.collections[collection]
        
        try:
            docs = self.db.collection(collection).stream()
            items = [doc.to_dict() for doc in docs]
            
            if items:
                preview = []
                for item in items[:5]:
                    display_name = (
                        item.get('title') or 
                        item.get('name') or 
                        item.get('Title') or
                        item.get('text') or
                        item.get('username') or
                        item.get('url') or
                        f"Item {item.get('id', 'N/A')}"
                    )
                    preview.append(f"• {display_name} (ID: {item.get('id', 'N/A')})")
                
                text = f"📋 {collection_info['name']} ({len(items)} total):\n\n" + "\n".join(preview)
                if len(items) > 5:
                    text += f"\n\n... and {len(items) - 5} more items"
            else:
                text = f"No {collection_info['name'].lower()} found."
            
            await query.edit_message_text(
                text,
                reply_markup=self.get_back_to_menu_keyboard()
            )
            
        except Exception as e:
            logger.error(f"Error showing collection data: {e}")
            await query.edit_message_text(
                "❌ Error loading data.",
                reply_markup=self.get_back_to_menu_keyboard()
            )

    async def show_statistics(self, update: Update):
        await self._show_stats(update.message.reply_text)

    async def show_statistics_callback(self, query):
        await self._show_stats(lambda text, **kwargs: query.edit_message_text(text, **kwargs))

    async def _show_stats(self, reply_func):
        try:
            stats_text = "📊 Veterinary Dictionary Statistics:\n\n"
            total = 0
            
            for collection_key, collection_info in self.collections.items():
                count = self.get_collection_count(collection_key)
                stats_text += f"{collection_info['emoji']} {collection_info['name']}: {count}\n"
                total += count
            
            stats_text += f"\nTotal Records: {total}"
            stats_text += f"\n\nNote: This matches the exact structure and fields of the website admin panel."
            
            await reply_func(
                stats_text,
                reply_markup=self.get_back_to_menu_keyboard()
            )
            
        except Exception as e:
            logger.error(f"Error showing statistics: {e}")
            await reply_func(
                "❌ Error loading statistics.",
                reply_markup=self.get_back_to_menu_keyboard()
            )

    def get_collection_count(self, collection_key: str) -> int:
        try:
            docs = self.db.collection(collection_key).stream()
            return len([doc for doc in docs])
        except Exception as e:
            logger.error(f"Error getting collection count: {e}")
            return 0

    async def search_in_collection(self, collection: str, search_term: str) -> list:
        """Search for items in a collection based on the search term"""
        if not self.db:
            return []
        
        try:
            # Get all documents from the collection
            docs = self.db.collection(collection).stream()
            results = []
            
            search_lower = search_term.lower()
            
            for doc in docs:
                data = doc.to_dict()
                # Search in all text fields
                found = False
                
                for field_name in self.collections[collection]['fields']:
                    field_value = data.get(field_name, '')
                    if isinstance(field_value, str) and search_lower in field_value.lower():
                        found = True
                        break
                
                if found:
                    results.append(data)
            
            return results
            
        except Exception as e:
            logger.error(f"Error searching collection {collection}: {e}")
            return []

    def get_item_display_name(self, item: dict, collection: str) -> str:
        """Get a display name for an item based on its collection type"""
        if collection == 'words':
            return item.get('name', 'Unnamed word')
        elif collection == 'drugs':
            return item.get('name', 'Unnamed drug')
        elif collection == 'books':
            return item.get('title', 'Untitled book')
        elif collection == 'diseases':
            return item.get('name', 'Unnamed disease')
        elif collection == 'staff':
            return item.get('name', 'Unnamed staff')
        elif collection == 'tutorialVideos':
            return item.get('Title', 'Untitled video')
        elif collection == 'questions':
            text = item.get('text', 'No text')
            return text[:50] + "..." if len(text) > 50 else text
        elif collection == 'notifications':
            return item.get('title', 'Untitled notification')
        elif collection == 'users':
            return item.get('username', 'Unnamed user')
        elif collection == 'normalRanges':
            return item.get('name', 'Unnamed range')
        elif collection == 'appLinks':
            return item.get('url', 'No URL')
        else:
            return f"Item {item.get('id', 'N/A')}"

    def run(self):
        application = Application.builder().token(self.bot_token).build()
        
        application.add_handler(CommandHandler("start", self.start_command))
        application.add_handler(CommandHandler("help", self.help_command))
        application.add_handler(CommandHandler("menu", self.menu_command))
        application.add_handler(CommandHandler("stats", self.stats_command))
        application.add_handler(CommandHandler("collections", self.collections_command))
        application.add_handler(CallbackQueryHandler(self.handle_callback_query))
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, self.handle_text_message))
        
        logger.info("Starting Veterinary Dictionary Telegram Bot...")
        print("Bot is running! Go to Telegram and send /start to your bot.")
        print("Bot username: @VETDICT_ADMIN_BOT")
        # Use drop_pending_updates to ensure previous polling sessions are terminated and avoid 409 Conflict errors
        application.run_polling(allowed_updates=Update.ALL_TYPES, drop_pending_updates=True)

def main():
    try:
        bot = VetDictionaryBot()
        bot.run()
    except Exception as e:
        logger.error(f"Failed to start bot: {e}")
        raise

if __name__ == "__main__":
    main()