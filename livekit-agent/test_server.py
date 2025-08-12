#!/usr/bin/env python3
"""
Test script for the LiveKit token server
"""

import requests
import json
import os
from dotenv import load_dotenv

load_dotenv()

def test_token_server():
    # Test data
    server_url = "http://localhost:8080"
    test_data = {
        "roomName": "test-room",
        "participantName": "test-participant"
    }
    
    print("Testing LiveKit Token Server...")
    print(f"Server URL: {server_url}")
    print(f"Test data: {test_data}")
    print("-" * 50)
    
    try:
        # Test health endpoint
        print("1. Testing health endpoint...")
        health_response = requests.get(f"{server_url}/health", timeout=5)
        print(f"Health check status: {health_response.status_code}")
        if health_response.status_code == 200:
            print("✅ Health check passed")
        else:
            print("❌ Health check failed")
            return
        
        print("\n2. Testing token generation...")
        # Test token endpoint
        token_response = requests.post(
            f"{server_url}/token",
            headers={"Content-Type": "application/json"},
            json=test_data,
            timeout=10
        )
        
        print(f"Token generation status: {token_response.status_code}")
        
        if token_response.status_code == 200:
            result = token_response.json()
            print("✅ Token generation successful!")
            print("\nResponse:")
            print(json.dumps(result, indent=2))
            
            # Validate response structure
            required_fields = ['serverUrl', 'roomName', 'participantName', 'participantToken']
            missing_fields = [field for field in required_fields if field not in result]
            
            if missing_fields:
                print(f"⚠️  Missing fields in response: {missing_fields}")
            else:
                print("✅ All required fields present in response")
                
            # Check if token is valid JWT format (basic check)
            token = result.get('participantToken', '')
            if token.count('.') == 2:
                print("✅ Token appears to be valid JWT format")
            else:
                print("⚠️  Token doesn't appear to be valid JWT format")
                
        else:
            print("❌ Token generation failed")
            print(f"Response: {token_response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Could not connect to token server. Make sure it's running on port 8080.")
    except requests.exceptions.Timeout:
        print("❌ Request timed out. Server might be overloaded.")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")

if __name__ == "__main__":
    test_token_server()
