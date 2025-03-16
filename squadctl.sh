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

    # Vérifie si une instance de SquadGameServer tourne
    SERVER_PIDS=$(ps aux | grep "$SERVER_BIN" | grep -v grep | awk '{print $2}')

    if [ -n "$SERVER_PIDS" ]; then
        echo -e "✅ Le serveur Squad est \e[32mactif\e[0m (PID: $SERVER_PIDS)."
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

    SERVER_PIDS=$(ps aux | grep "$SERVER_BIN" | grep -v grep | awk '{print $2}')
    if [ -n "$SERVER_PIDS" ]; then
        echo -e "✅ Serveur Squad est \e[32mACTIF\e[0m (PID: $SERVER_PIDS)."

        # Afficher les ports utilisés par le serveur
        echo -e "ℹ️ Ports ouverts par le serveur :"
        sudo ss -tulnp | grep "$SERVER_BIN" | awk '{print "   - Port : " $5}' | sort -u

        # Vérifier le nombre de joueurs connectés
        PLAYER_COUNT=$(sudo ss -tulnp | grep ":7777" | wc -l)
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

    # Vérifie si le serveur est déjà en cours d'exécution
    if ps aux | grep "$SERVER_BIN" | grep -v grep > /dev/null; then
        echo "⚠️ Une instance du serveur tourne déjà. Annulation."
        return
    fi

    if [ -z "$SERVER_DIR" ] || [ -z "$SERVER_BIN" ]; then
        echo "❌ Erreur : Chemin du serveur ou exécutable non défini."
        return
    fi

    cd "$SERVER_DIR" || { echo -e "❌ Impossible d'accéder au répertoire $SERVER_DIR"; exit 1; }

    if [ ! -f "$SERVER_BIN" ]; then
        echo -e "❌ Erreur : '$SERVER_BIN' introuvable dans '$SERVER_DIR'"
        return
    fi

    if [ -n "$SERVER_USER" ]; then
        sudo -u "$SERVER_USER" screen -dmS "$SCREEN_NAME" ./"$SERVER_BIN"
    else
        screen -dmS "$SCREEN_NAME" ./"$SERVER_BIN"
    fi

    sleep 3
    server_status && open_ports
}

# Arrêter le serveur
server_stop() {
    echo "--------------------"
    echo "🛑 Tentative d'arrêt du serveur..."

    # Récupérer tous les PID du serveur
    SERVER_PIDS=$(ps aux | grep "$SERVER_BIN" | grep -v grep | awk '{print $2}')
    
    if [ -n "$SERVER_PIDS" ]; then
        echo "⚠️ Arrêt de tous les processus SquadGameServer..."
        sudo pkill -f "$SERVER_BIN"
        sleep 3
    fi

    # Fermer toutes les sessions `screen`
    SCREEN_SESSIONS=$(screen -ls | grep "$SCREEN_NAME" | awk '{print $1}')
    if [ -n "$SCREEN_SESSIONS" ]; then
        echo "🛑 Fermeture des sessions screen..."
        for session in $SCREEN_SESSIONS; do
            screen -S "$session" -X quit
        done
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
