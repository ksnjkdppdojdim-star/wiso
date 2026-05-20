# wiso (plugin Trish)

Plugin dynamique **Windows** pour [Trish](https://github.com/ksnjkdppdojdim-star/trish) : raccourcis **Wi‑Fi** (`netsh wlan`), **interfaces**, **voisinage IPv4**, **ping**, **test de port** et **mini-scan TCP** (ports courants). Pensé pour l’audit interne sur un parc autorisé, pas comme remplacement de nmap.

## Prérequis

- Serveur Trish avec plugins activés, CLI admin.
- Agent Trish sur une machine **Windows** (PowerShell 5.1+).
- Droits suffisants pour `netsh wlan` (souvent **administrateur** pour `key=clear`).

## Installation (Git)

Sur la machine où tu exécutes le CLI (celle qui parle au serveur) :

```powershell
trish plugin install https://github.com/<ton-org>/wiso.git
```

Remplace l’URL par celle de ton dépôt une fois publié.

Vérifier :

```powershell
trish plugin list
trish plugin status <agent-id>
```

Tu dois voir la commande `wiso`.

## Utilisation

```powershell
trish exec <agent-id> wiso help
trish exec <agent-id> wiso profiles
trish exec <agent-id> wiso show "Nom du profil Wi‑Fi"
trish exec <agent-id> wiso key "Nom du profil Wi‑Fi"
```

Raccourci demandé (un seul argument = profil + clé en clair, comme `netsh ... key=clear`) :

```powershell
trish exec <agent-id> wiso "Nom du profil Wi‑Fi"
```

Réseau (léger) :

```powershell
trish exec <agent-id> wiso interfaces
trish exec <agent-id> wiso neighbors
trish exec <agent-id> wiso ping 192.168.1.1 3
trish exec <agent-id> wiso port 192.168.1.10 445
trish exec <agent-id> wiso scan 192.168.1.10
```

## Mise à jour

```powershell
trish plugin update https://github.com/<ton-org>/wiso.git
```

## Fichiers

| Fichier            | Rôle                                      |
| ------------------ | ----------------------------------------- |
| `trish-plugin.json` | Manifeste lu par `trish plugin install` |
| `wiso.ps1`         | Point d’entrée exécuté sur l’agent       |

## Sécurité et conformité

- Les commandes **`key`**, **`pw`** et le **raccourci un seul argument** exposent la **phrase secrète Wi‑Fi en clair**. Réserve-les aux **inventaires autorisés** et aux **postes dont tu es responsable**.
- `wiso scan` enchaîne des `Test-NetConnection` : reste raisonnable sur la cible et le contexte (usage interne, pas de scan agressif vers des réseaux tiers).

## Développement local

```powershell
trish plugin test "C:\chemin\vers\wiso"
```

## Licence

MIT (voir [LICENSE](LICENSE)).
