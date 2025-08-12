# server.py
import os
import json
from livekit import api
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import logging

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter web clients

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Health check endpoint
@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200

# Token generation endpoint for production
@app.route('/token', methods=['POST'])
def generate_token():
    try:
        # Get request data
        data = request.get_json()
        
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        room_name = data.get('roomName')
        participant_name = data.get('participantName')
        participant_identity = data.get('participantIdentity', participant_name)
        
        # Validate required fields
        if not room_name or not participant_name:
            return jsonify({"error": "roomName and participantName are required"}), 400
        
        # Get environment variables
        api_key = os.getenv('LIVEKIT_API_KEY')
        api_secret = os.getenv('LIVEKIT_API_SECRET')
        server_url = os.getenv('LIVEKIT_URL', 'ws://localhost:7880')
        
        if not api_key or not api_secret:
            logger.error("Missing LIVEKIT_API_KEY or LIVEKIT_API_SECRET")
            return jsonify({"error": "Server configuration error"}), 500
        
        # Create access token
        token = api.AccessToken(api_key, api_secret) \
            .with_identity(participant_identity) \
            .with_name(participant_name) \
            .with_grants(api.VideoGrants(
                room_join=True,
                room=room_name,
                # Add additional permissions as needed
                can_publish=True,
                can_subscribe=True,
                can_publish_data=True,
            ))
        
        # Generate JWT token
        jwt_token = token.to_jwt()
        
        # Return connection details
        response = {
            "serverUrl": server_url,
            "roomName": room_name,
            "participantName": participant_name,
            "participantToken": jwt_token
        }
        
        logger.info(f"Generated token for participant '{participant_name}' in room '{room_name}'")
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"Error generating token: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

# Legacy endpoint for backward compatibility
@app.route('/getToken')
def getToken():
    # Use default values for legacy endpoint
    room_name = request.args.get('room', 'my-room')
    participant_name = request.args.get('participant', 'anonymous')
    
    try:
        api_key = os.getenv('LIVEKIT_API_KEY')
        api_secret = os.getenv('LIVEKIT_API_SECRET')
        
        if not api_key or not api_secret:
            return jsonify({"error": "Server configuration error"}), 500
        
        token = api.AccessToken(api_key, api_secret) \
            .with_identity(participant_name) \
            .with_name(participant_name) \
            .with_grants(api.VideoGrants(
                room_join=True,
                room=room_name,
            ))
        
        return token.to_jwt()
        
    except Exception as e:
        logger.error(f"Error in legacy token endpoint: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    debug = os.getenv('FLASK_ENV') == 'development'
    
    logger.info(f"Starting token server on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)