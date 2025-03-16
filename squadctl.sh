#!/bin/bash

# Variables
SERVER_DIR=""  # Chemin vers le dossier contenant 'SquadGameServer'
SERVER_BIN="SquadGameServer"  # Nom de l'exécutable du serveur
SCREEN_NAME="squad"
SQUAD_PORTS=(7777 27165 15000)  # Ports utilisés par le serveur Squad
SERVER_USER=""  # Utilisateur sous lequel le serveur doit être exécuté (laisser vide par défaut)

# Vérifier si le serveur est actif
server_status() {
    echo "--------------------"
    echo "🔍 Vérification de l'état du serveur..."
    
    SERVER_PID=$(pgrep -u "$SERVER_USER" -f "$SERVER_BIN" | head -n 1)
    if [ -n "$SERVER_PID" ]; then
        echo -e "✅ Le serveur Squad est \e[32mactif\e[0m (PID: $SERVER_PID)."
        return 0
    else
        echo -e "❌ Le serveur Squad est \e[31minactif\e[0m."
        return 1
    fi
}

server_info() {
    echo "-------------------------------------------------------"
    echo -e "🌐 Informations sur le serveur Squad :"
    echo "-------------------------------------------------------"
    echo "🔍 Vérification des détails du serveur..."

    SERVER_PID=$(pgrep -u "$SERVER_USER" -f "$SERVER_BIN" | head -n 1)
    if [ -n "$SERVER_PID" ]; then
        echo -e "✅ Serveur Squad est \e[32mACTIF\e[0m (PID: $SERVER_PID)."
        echo -e "ℹ️ Ports ouverts par le serveur :"
        ss -tulnp | grep "SquadGameServer" | awk '{print "   - Port : " $5}' | sort -u
        PLAYER_COUNT=$(ss -tulnp | grep :7777 | wc -l)
        echo -e "👤 Joueurs connectés : $PLAYER_COUNT"
    else
        echo -e "❌ Le serveur est \e[31mINACTIF\e[0m."
    fi
    echo "🔍 Vérification des règles UFW..."
    sudo ufw status numbered
}

# Démarrer le serveur
server_start() {
    echo "--------------------"
    echo "🚀 Tentative de démarrage du serveur..."
    if screen -list | grep -q "$SCREEN_NAME"; then
        echo -e "⚠️ Le serveur est déjà démarré."
    else
        echo -e "✅ Démarrage du serveur Squad..."
        cd "$SERVER_DIR" || { echo -e "❌ Impossible d'accéder au répertoire $SERVER_DIR"; exit 1; }
        if [ ! -f "$SERVER_BIN" ]; then
            echo -e "❌ Erreur : '$SERVER_BIN' introuvable dans '$SERVER_DIR'"
            exit 1
        fi
        if [ -n "$SERVER_USER" ]; then
            sudo -u "$SERVER_USER" bash -c "cd $SERVER_DIR && screen -dmS $SCREEN_NAME ./$SERVER_BIN"
        else
            screen -dmS "$SCREEN_NAME" "./$SERVER_BIN"
        fi
        sleep 3
        server_status && open_ports
    fi
}

# Arrêter le serveur
server_stop() {
    echo "--------------------"
    echo "🛑 Tentative d'arrêt du serveur..."
    
    SERVER_PIDS=$(pgrep -u "$SERVER_USER" -f "$SERVER_BIN")
    if [ -n "$SERVER_PIDS" ]; then
        echo -e "⚠️ Arrêt des processus liés à SquadGameServer..."
        for PID in $SERVER_PIDS; do
            sudo kill -SIGTERM "$PID" 2>/dev/null
            sleep 1
            sudo kill -SIGKILL "$PID" 2>/dev/null
        done
    fi
    
    if screen -list | grep -q "$SCREEN_NAME"; then
        echo -e "⚠️ Suppression de la session screen..."
        screen -S "$SCREEN_NAME" -X quit
    fi
    
    sleep 3
    server_status
    close_ports
}

# Redémarrer le serveur
server_restart() {
    echo "--------------------"
    echo "🔄 Redémarrage du serveur Squad..."
    server_stop
    sleep 3
    server_start
}

# Ouvrir les ports avec UFW
open_ports() {
    echo "--------------------"
    echo -e "✅ Ouverture des ports pour le serveur Squad..."
    for port in "${SQUAD_PORTS[@]}"; do
        echo "🔓 Autorisation du port $port/udp"
        sudo ufw allow $port/udp
    done
    echo "🔍 Vérification des règles UFW..."
    sudo ufw status
    echo -e "ℹ️ Ports ouverts avec succès."
}

# Fermer les ports avec UFW
close_ports() {
    echo "--------------------"
    echo -e "❌ Fermeture des ports pour le serveur Squad..."
    for port in "${SQUAD_PORTS[@]}"; do
        echo "🔒 Restriction du port $port/udp"
        sudo ufw deny $port/udp
    done
    echo "🔍 Vérification des règles UFW..."
    sudo ufw status
    echo -e "ℹ️ Ports fermés avec succès."
}

# Afficher l'utilisation
usage() {
    echo -e "Utilisation : $0 {start|stop|restart|status|info|open_ports|close_ports}"
    exit 1
}

# Gestion des arguments
case "$1" in
    start)
        server_start
        ;;
    stop)
        server_stop
        ;;
    restart)
        server_restart
        ;;
    status)
        server_status
        ;;
    info)
        server_info
        ;;
    open_ports)
        open_ports
        ;;
    close_ports)
        close_ports
        ;;
    *)
        usage
        ;;
esac
