#!/usr/bin/env python3
"""
Telegram Bot Runner Script
"""

import os
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def check_requirements():
    required_vars = ['TELEGRAM_BOT_TOKEN']
    missing_required = [var for var in required_vars if not os.getenv(var)]
    
    if missing_required:
        print("❌ Missing required environment variables:")
        for var in missing_required:
            print(f"   - {var}")
        print("\nPlease set these variables in your .env file or environment.")
        return False
    
    return True

def main():
    print("🤖 Starting Veterinary Dictionary Telegram Bot...")
    
    if not check_requirements():
        sys.exit(1)
    
    try:
        from bot import VetDictionaryBot
        
        bot = VetDictionaryBot()
        print("✅ Bot initialized successfully!")
        print("🚀 Bot is now running... Press Ctrl+C to stop.")
        
        bot.run()
        
    except KeyboardInterrupt:
        print("\n🛑 Bot stopped by user.")
        sys.exit(0)
    except Exception as e:
        print(f"❌ Error starting bot: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()