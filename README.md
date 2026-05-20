# wiso (plugin Trish)

Plugin dynamique **Windows** pour [Trish](https://github.com/ksnjkdppdojdim-star/trish) : raccourcis **Wi‑Fi** (`netsh wlan`), **interfaces**, **voisins**, **ping**, **test de port** et **mini-scan TCP**. Usage interne sur un parc autorisé.

## Architecture du dépôt

Le point d’entrée Trish reste **`wiso.ps1`** (champ `entry` du manifeste). Il charge les modules dans l’ordre, puis appelle le routeur.

```text
wiso/
  trish-plugin.json     # manifeste Trish
  wiso.ps1              # bootstrap : charge modules\*.ps1, try/catch global
  modules/
    Wiso.Common.ps1     # mots réservés, erreurs d’usage, Invoke-WisoWithErrorContext
    Wiso.Help.ps1       # texte d’aide
    Wiso.Wlan.ps1       # profils / détails / clés Wi‑Fi (netsh)
    Wiso.Network.ps1    # interfaces, ARP rapide, ping.exe, TCP court, scan
    Wiso.Machine.ps1    # who
    Wiso.Dispatch.ps1   # routage des sous-commandes + contexte d’erreur par branche
  README.md
  LICENSE
```

Chaque branche métier vit dans son fichier ; `Wiso.Dispatch.ps1` orchestre et enveloppe les exceptions avec un préfixe `wiso [branche] ...` pour faciliter le diagnostic.

## Timeouts `read tcp ... i/o timeout` (port 9999)

Le message vient en général du **client admin Trish** : la requête `cli -> serveur -> agent -> retour` doit tenir dans le **délai global** configuré côté CLI (souvent de l’ordre de **quelques secondes** sur les builds actuelles). Si la commande distante dépasse ce délai, la lecture TCP côté CLI expire.

**Changements côté wiso 0.2.0 pour limiter le problème :**

- **`wiso neighbors`** utilise par défaut **`arp -a`** (très rapide) au lieu de `Get-NetNeighbor` (souvent plus lent).
- **`wiso neighbors win`** conserve la vue **Get-NetNeighbor** (plus riche, mais peut encore dépasser le délai sur certaines machines).
- **`wiso ping`** passe par **`ping.exe`** avec **`-w`** borné.
- **`wiso port`** et **`wiso scan`** utilisent des **connexions TCP courtes** (timeouts courts par port).

**Si ça timeout encore :** augmenter le timeout côté **Trish** (CLI / client) ou alléger la commande ; le plugin seul ne peut pas allonger le délai imposé par le binaire `trish`.

## Prérequis

- Serveur Trish avec plugins, CLI admin.
- Agent Trish sur **Windows** (PowerShell 5.1+).
- Droits suffisants pour `netsh wlan` (souvent **administrateur** pour `key=clear`).

## Installation (Git)

```powershell
trish plugin install https://github.com/<ton-org>/wiso.git
```

Puis :

```powershell
trish plugin list
trish plugin status <agent-id>
```

## Utilisation

```powershell
trish exec <agent-id> wiso help
trish exec <agent-id> wiso profiles
trish exec <agent-id> wiso show "Nom du profil Wi-Fi"
trish exec <agent-id> wiso key "Nom du profil Wi-Fi"
trish exec <agent-id> wiso "Nom du profil Wi-Fi"
```

Réseau :

```powershell
trish exec <agent-id> wiso interfaces
trish exec <agent-id> wiso neighbors
trish exec <agent-id> wiso neighbors win
trish exec <agent-id> wiso ping 192.168.1.1 3
trish exec <agent-id> wiso port 192.168.1.10 445
trish exec <agent-id> wiso scan 192.168.1.10
```

## Mise à jour

```powershell
trish plugin update https://github.com/<ton-org>/wiso.git
```

## Développement local

```powershell
trish plugin test "C:\chemin\vers\wiso"
```

## Sécurité

- **`key`**, **`pw`** et le **raccourci un seul argument** exposent la **phrase secrète Wi‑Fi en clair**. Réserver aux inventaires autorisés.
- **`scan`** : usage interne raisonnable uniquement.

## Licence

MIT (voir [LICENSE](LICENSE)).
