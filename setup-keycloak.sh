#!/usr/bin/env bash

# =================================================================
# GeoNode Keycloak Setup Script (Multi-Platform)
# =================================================================
# Funziona su Linux, Mac e Windows (con Git Bash/WSL)
# Utilizza Docker per standardizzare l'ambiente

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo -e "\n${YELLOW}🔄 $1${NC}"
}

echo -e "${GREEN}"
echo "=================================================="
echo "GeoNode Keycloak Setup"
echo "=================================================="
echo -e "${NC}"

# Verifica Docker
print_step "Verifica Docker..."
if ! command -v docker &> /dev/null; then
    print_error "Docker non è installato o non è nel PATH"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose non è installato o non è nel PATH"
    exit 1
fi

print_status "Docker e Docker Compose trovati"

# Verifica file .env
print_step "Verifica configurazione..."
if [ ! -f ".env" ]; then
    print_warning "File .env non trovato!"
    print_info "Creazione .env da template..."
    
    if [ -f ".env.template" ]; then
        cp .env.template .env
        print_status "File .env creato da template"
        print_warning "IMPORTANTE: Modifica .env con le tue credenziali Keycloak prima di continuare!"
        print_info "Variabili da configurare:"
        echo "   - KEYCLOAK_SERVER_URL"
        echo "   - KEYCLOAK_REALM" 
        echo "   - KEYCLOAK_CLIENT_ID"
        echo "   - KEYCLOAK_CLIENT_SECRET"
        echo ""
        read -p "Premi ENTER dopo aver configurato .env per continuare..."
    else
        print_error "File .env.template non trovato!"
        exit 1
    fi
fi

# Carica e verifica variabili
print_step "Verifica variabili Keycloak..."
source .env

required_vars=("KEYCLOAK_SERVER_URL" "KEYCLOAK_REALM" "KEYCLOAK_CLIENT_ID" "KEYCLOAK_CLIENT_SECRET")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    print_error "Variabili mancanti nel file .env:"
    printf '   - %s\n' "${missing_vars[@]}"
    exit 1
fi

print_status "Configurazione .env verificata"

# Build dell'immagine
print_step "Build immagine GeoNode con integrazione Keycloak..."
docker-compose build django

if [ $? -ne 0 ]; then
    print_error "Errore durante il build dell'immagine"
    exit 1
fi

print_status "Build completato"

# Avvio servizi
print_step "Avvio servizi GeoNode..."
docker-compose up -d

if [ $? -ne 0 ]; then
    print_error "Errore durante l'avvio dei servizi"
    exit 1
fi

print_status "Servizi avviati"

# Attesa Django
print_step "Attesa avvio Django..."
timeout=300
counter=0

while ! docker-compose exec -T django python -c "import django; print('ready')" &>/dev/null; do
    sleep 5
    counter=$((counter + 5))
    echo "   Attesa Django... (${counter}s/${timeout}s)"
    
    if [ $counter -ge $timeout ]; then
        print_error "Timeout: Django non si è avviato entro $timeout secondi"
        print_info "Controlla i log: docker-compose logs django"
        exit 1
    fi
done

print_status "Django pronto"

# Setup Social App
print_step "Configurazione Social App Keycloak..."
docker-compose exec -T django python manage.py setup_keycloak

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}"
    echo "=================================================="
    echo "Setup completato con successo!"
    echo "=================================================="
    echo -e "${NC}"
    
    print_info "Accesso:"
    echo "   GeoNode: http://localhost/"
    echo "   Login: http://localhost/account/login/"
    echo "   Admin: http://localhost/admin/"
    echo "   GeoServer: http://localhost/geoserver/"
    
    print_info "Test integrazione Keycloak:"
    echo "   1. Vai su http://localhost/account/login/"
    echo "   2. Clicca 'Login with GeoNode OpenIDConnect'"
    echo "   3. Effettua login tramite Keycloak"
    
    print_info "Comandi utili:"
    echo "   Log Django: docker-compose logs django -f"
    echo "   Restart: docker-compose restart django"
    echo "   Stop: docker-compose down"
    
else
    print_error "Errore durante la configurazione della Social App"
    print_info "Controlla i log: docker-compose logs django"
    exit 1
fi