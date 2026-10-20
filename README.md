# production-kit

Configurations de déploiement et de durcissement pour applications web auto-hébergées sur VPS.

Ce dépôt rassemble ce que j'utilise réellement en production sur les projets que j'exploite : conteneurisation, reverse proxy, TLS, durcissement serveur, sauvegardes vérifiées, déploiement continu avec retour arrière, et supervision.

Il ne s'agit pas d'un tutoriel. Ce sont des fichiers de travail, dépouillés de toute donnée client.

---

## Pourquoi

Beaucoup d'applications fonctionnent correctement en local et tiennent mal en production. Les causes se répètent :

- la base de données écoute sur une interface publique ;
- le conteneur tourne en root ;
- aucune limitation de débit sur l'authentification ;
- des sauvegardes existent mais n'ont jamais été restaurées ;
- personne ne sait redéployer sans le développeur d'origine ;
- la panne est signalée par un client, pas par une alerte.

Chaque fichier de ce dépôt répond à l'un de ces points.

---

## Contenu

### `docker/`

**`Dockerfile.node`** : build multi-étapes. Image finale sans dépendances de développement, exécution sous un utilisateur non privilégié, `HEALTHCHECK` intégré pour que l'orchestrateur sache si le conteneur répond vraiment.

**`docker-compose.prod.yml`** : application, PostgreSQL, Redis, Nginx et renouvellement automatique des certificats.

Deux choix structurants :

- la base et le cache sont sur un réseau `internal`, **sans aucun port publié sur l'hôte**. Ils ne sont joignables que par l'application ;
- les dépendances déclarent `condition: service_healthy`, donc l'application ne démarre pas avant que la base réponde.

### `nginx/`

Reverse proxy avec TLS 1.2 et 1.3, agrafage OCSP, et une configuration de chiffrements qui obtient la note A sur SSL Labs.

Les en-têtes de sécurité sont regroupés dans un fragment réutilisable : HSTS avec préchargement, CSP, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, et suppression de la bannière de version.

La limitation de débit est différenciée : cinq requêtes par minute sur la connexion, trente par seconde sur l'API. Le premier quota rend le bourrage d'identifiants impraticable, le second protège du reste.

Une section dédiée gère les WebSockets avec un délai d'attente long.

### `scripts/`

**`harden-server.sh`** : durcissement d'un VPS Ubuntu ou Debian neuf. SSH par clé uniquement, root interdit, port configurable, trois tentatives maximum. Pare-feu UFW en refus par défaut. Fail2ban sur SSH et sur Nginx. Mises à jour de sécurité automatiques. Paramètres noyau.

Le fichier de configuration SSH est sauvegardé avant modification et la syntaxe validée avant rechargement. Le script rappelle en fin d'exécution de vérifier la connexion **avant** de fermer la session courante, parce que se verrouiller dehors est l'erreur classique.

**`backup-postgres.sh`** : export au format personnalisé, puis **vérification systématique de l'archive** par `pg_restore --list`. Une archive illisible est supprimée et le script échoue. Rotation configurable et copie hors site optionnelle.

Une sauvegarde qu'on n'a jamais tenté de relire n'est pas une sauvegarde.

**`restore-postgres.sh`** : la procédure inverse, avec confirmation explicite. À exécuter en recette au moins une fois par trimestre. Un plan de restauration jamais testé est une hypothèse.

### `.github/workflows/deploy.yml`

Déploiement continu en deux étapes.

La première refuse de continuer si le lint, les tests ou `npm audit --audit-level=high` échouent.

La seconde déploie, puis interroge l'URL de santé pendant deux minutes. **Si le service ne répond pas, le commit précédent est automatiquement restauré et reconstruit.** Le SHA de la version en cours est sauvegardé avant toute modification.

Un verrou de concurrence empêche deux déploiements simultanés.

### `monitoring/uptime-check.sh`

Sonde à placer en tâche planifiée toutes les cinq minutes. Elle n'alerte qu'après trois échecs consécutifs, soit quinze minutes, afin d'éviter le bruit sur une coupure passagère, et signale également le rétablissement.

---

## Utilisation

```bash
# 1. Durcir le serveur, une seule fois, en root
./scripts/harden-server.sh deploy 2222

# 2. Renseigner les variables
cp .env.example .env.production

# 3. Démarrer
docker compose -f docker/docker-compose.prod.yml up -d

# 4. Planifier sauvegardes et supervision
0 3 * * *   /srv/app/scripts/backup-postgres.sh
*/5 * * * * /srv/app/monitoring/uptime-check.sh
```

Adapter `nginx/conf.d/app.conf` : remplacer `example.com` et vérifier le port applicatif.

---

## Avertissement

Ces fichiers sont des points de départ éprouvés, pas des configurations universelles. Lisez `harden-server.sh` avant de l'exécuter : il modifie SSH et le pare-feu, et une erreur de paramètre peut vous couper l'accès au serveur.

---

## Contexte

Je suis développeur backend Python (Django, FastAPI), en remote depuis le Bénin, fuseau GMT+1.

Je conçois, développe et exploite des plateformes web en production. Les dépôts de mes projets clients sont privés, ce qui explique qu'ils n'apparaissent pas ici. Ce dépôt montre la partie qui se transpose d'un projet à l'autre : la mise en production et son exploitation.

Portfolio : [obafemiagnoun.cloud](https://obafemiagnoun.cloud)
LinkedIn : [obafemieuloge](https://linkedin.com/in/obafemieuloge)

## Licence

MIT
