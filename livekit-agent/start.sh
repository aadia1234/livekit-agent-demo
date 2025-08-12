#!/bin/bash

# Start script for running both token server and agent

# Function to start the token server
start_token_server() {
    echo "Starting token server on port 8080..."
    python server.py &
    TOKEN_SERVER_PID=$!
    echo "Token server started with PID: $TOKEN_SERVER_PID"
}

# Function to start the agent
start_agent() {
    echo "Starting LiveKit agent..."
    python agent.py &
    AGENT_PID=$!
    echo "Agent started with PID: $AGENT_PID"
}

# Function to handle shutdown
shutdown() {
    echo "Shutting down services..."
    if [ ! -z "$TOKEN_SERVER_PID" ]; then
        kill $TOKEN_SERVER_PID
        echo "Token server stopped"
    fi
    if [ ! -z "$AGENT_PID" ]; then
        kill $AGENT_PID
        echo "Agent stopped"
    fi
    exit 0
}

# Set up signal handlers
trap shutdown SIGTERM SIGINT

# Start services based on environment variable
case "${SERVICE}" in
    "token-server")
        echo "Starting token server only..."
        start_token_server
        wait $TOKEN_SERVER_PID
        ;;
    "agent")
        echo "Starting agent only..."
        start_agent
        wait $AGENT_PID
        ;;
    "both"|*)
        echo "Starting both services..."
        start_token_server
        start_agent
        
        # Wait for both processes
        wait
        ;;
esac
