#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# WEHTTAMSNAPS AUDIO ROUTING SETUP
# ════════════════════════════════════════════════════════════════════════════════
# Sets up PipeWire virtual sinks for streaming
# VoiceMeeter-like audio routing for OBS

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ────────────────────────────────────────────────────────────────────────────────
# Check PipeWire
# ────────────────────────────────────────────────────────────────────────────────
check_pipewire() {
    if ! pgrep -x pipewire &> /dev/null; then
        echo -e "${RED}Error: PipeWire is not running${NC}"
        echo "Start PipeWire first: systemctl --user start pipewire pipewire-pulse"
        exit 1
    fi
    echo -e "${GREEN}✓ PipeWire is running${NC}"
}

# ────────────────────────────────────────────────────────────────────────────────
# Create Virtual Sinks
# ────────────────────────────────────────────────────────────────────────────────
create_virtual_sinks() {
    echo -e "${CYAN}🔊 Creating virtual audio sinks...${NC}"
    
    # Create virtual sinks for different audio sources
    # These can be used in OBS to capture specific audio
    
    # Game audio sink
    pw-cli create-node adapter '{ 
        factory.name=audiosink 
        node.name="game-audio" 
        node.description="Game Audio" 
        media.class="Audio/Sink" 
        audio.channels=2 
        audio.position="[FL FR]"
    }' 2>/dev/null || echo -e "${YELLOW}  Game audio sink already exists or failed${NC}"
    
    # Browser/Discord audio sink
    pw-cli create-node adapter '{ 
        factory.name=audiosink 
        node.name="browser-audio" 
        node.description="Browser Audio" 
        media.class="Audio/Sink" 
        audio.channels=2 
        audio.position="[FL FR]"
    }' 2>/dev/null || echo -e "${YELLOW}  Browser audio sink already exists or failed${NC}"
    
    # Music audio sink
    pw-cli create-node adapter '{ 
        factory.name=audiosink 
        node.name="music-audio" 
        node.description="Music Audio" 
        media.class="Audio/Sink" 
        audio.channels=2 
        audio.position="[FL FR]"
    }' 2>/dev/null || echo -e "${YELLOW}  Music audio sink already exists or failed${NC}"
    
    # Microphone passthrough
    pw-cli create-node adapter '{ 
        factory.name=audiosink 
        node.name="mic-passthrough" 
        node.description="Mic Passthrough" 
        media.class="Audio/Sink" 
        audio.channels=2 
        audio.position="[FL FR]"
    }' 2>/dev/null || echo -e "${YELLOW}  Mic passthrough sink already exists or failed${NC}"
    
    echo -e "${GREEN}✓ Virtual sinks created${NC}"
}

# ────────────────────────────────────────────────────────────────────────────────
# List Audio Devices
# ────────────────────────────────────────────────────────────────────────────────
list_audio_devices() {
    echo -e "${CYAN}📋 Available audio devices:${NC}\n"
    
    echo -e "${YELLOW}Output devices (speakers/headphones):${NC}"
    wpctl status | grep -A 20 "Audio" | grep -E "^[[:space:]]+[0-9]+" | head -10
    
    echo -e "\n${YELLOW}Input devices (microphones):${NC}"
    wpctl status | grep -A 20 "Audio" | grep -E "麦克风|Microphone|\[in\]" | head -5 || true
}

# ────────────────────────────────────────────────────────────────────────────────
# Launch qpwgraph
# ────────────────────────────────────────────────────────────────────────────────
launch_qpwgraph() {
    echo -e "${CYAN}🔊 Launching qpwgraph for visual audio routing...${NC}"
    
    if ! command -v qpwgraph &> /dev/null; then
        echo -e "${RED}Error: qpwgraph is not installed${NC}"
        echo "Install with: sudo pacman -S qpwgraph"
        exit 1
    fi
    
    qpwgraph &
    echo -e "${GREEN}✓ qpwgraph launched${NC}"
}

# ────────────────────────────────────────────────────────────────────────────────
# Show Help
# ────────────────────────────────────────────────────────────────────────────────
show_help() {
    cat << EOF
${CYAN}WehttamSnaps Audio Setup${NC}
VoiceMeeter-like audio routing for PipeWire

${YELLOW}Usage:${NC}
  audio-setup.sh [command]

${YELLOW}Commands:${NC}
  check       Check if PipeWire is running
  create      Create virtual audio sinks
  list        List available audio devices
  graph       Launch qpwgraph for visual routing
  all         Run complete setup (check + create)
  help        Show this help

${YELLOW}Examples:${NC}
  audio-setup.sh all
  audio-setup.sh create
  audio-setup.sh graph

${YELLOW}Virtual Sinks Created:${NC}
  • game-audio      - For game audio capture
  • browser-audio   - For browser/Discord audio
  • music-audio     - For Spotify/music apps
  • mic-passthrough - For microphone routing

${YELLOW}OBS Integration:${NC}
  1. In OBS, add "Audio Output Capture" source
  2. Select PipeWire as device type
  3. Choose the virtual sink you want to capture

EOF
}

# ────────────────────────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────────────────────────
case "${1:-help}" in
    check)
        check_pipewire
        ;;
    create)
        check_pipewire
        create_virtual_sinks
        ;;
    list)
        list_audio_devices
        ;;
    graph|qpwgraph)
        launch_qpwgraph
        ;;
    all)
        check_pipewire
        create_virtual_sinks
        echo -e "\n${CYAN}Launching qpwgraph for routing configuration...${NC}"
        launch_qpwgraph
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac