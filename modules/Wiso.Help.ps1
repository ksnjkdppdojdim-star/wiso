#Requires -Version 5.1
# Texte d'aide centralise.

function Get-WisoHelpText {
    $ver = Get-WisoVersion
    @"
wiso $ver - audit reseau / Wi-Fi (usage interne, machines autorisees uniquement)

Wi-Fi
  wiso profiles              Liste des profils WLAN enregistres
  wiso wifi                  Connexion WLAN active (netsh wlan show interfaces)
  wiso show <profil>         Detail du profil sans cle en clair
  wiso key <profil>          Profil + cle en clair (key=clear) - sensible
  wiso "<profil>"            Raccourci : comme "wiso key <profil>" (un seul argument)

Reseau
  wiso interfaces            Adresses IPv4 par interface
  wiso neighbors             Table ARP complete (arp -a, encodage corrige)
  wiso neighbors brief       Voisins utiles uniquement (sans multicast)
  wiso neighbors win         Get-NetNeighbor (plus lent)
  wiso route                 Routes IPv4 (route print -4)
  wiso dns                   Serveurs DNS par interface
  wiso gateway               Passerelle par defaut + ping rapide
  wiso lan [max]             Ping sweep /24 borne (defaut 24 hotes, max 32)
  wiso ping <hote> [n]       Ping ICMP (ping.exe, -w 1200 ms)
  wiso port <hote> <port>    Test TCP rapide
  wiso scan <hote>           Ports TCP courants (8 ports)
  wiso scan quick <hote>     Scan rapide (80,443,445,3389)
  wiso quick scan <hote>     Alias scan rapide
  wiso portscan <h> <ports>  Ports personnalises (max 12, ex: 80,443,8080)

Securite locale
  wiso firewall              Etat des profils pare-feu Windows
  wiso listeners             Ports TCP en ecoute (top 80)
  wiso shares                Partages locaux (net share)

Machine
  wiso who                   Hostname + utilisateur
  wiso version               Version du plugin wiso

Aide
  wiso help

Timeouts Trish : delai court cote CLI (~5 s). Preferer neighbors brief, scan quick, lan avec max bas.
"@
}
