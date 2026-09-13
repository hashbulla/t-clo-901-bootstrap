# Solutions

> Ouvrez ce fichier après dix minutes de recherche sur un exercice, pas avant. La valeur du bootstrap est dans le diagnostic, pas dans la commande.

## Bloc 1

### 1.1

Trois services. `traefik` est un reverse proxy qui lit le socket Docker pour découvrir les conteneurs à exposer ; `app` est PHP 8.2 + Apache, construit localement ; `db` est MySQL 8. `app` joint `db` par le nom `db`, résolu par le DNS interne de Compose. Deux chemins vers l'application : le port 80 via Traefik, le port 8081 en direct sur `app`. Mots de passe et `APP_KEY` en clair dans le YAML. `db_data` est un volume nommé monté sur `/var/lib/mysql`.

Réponses acceptables à la question : secrets en clair, `composer:latest` non épinglé, `APP_DEBUG=true`, socket Docker monté dans Traefik, `depends_on` sans condition de santé, pas de politique de redémarrage sur `app`, `mysql_native_password`, aucune limite de ressources. Chacune de ces lignes est un sujet que vous retrouverez.

### 1.2

Symptôme : `composer install` échoue avec « The /var/www/html/bootstrap/cache directory must be present and writable ». Cause : l'archive a perdu les dossiers vides et les fichiers cachés. Le `chown` du Dockerfile échouerait ensuite sur `storage/` pour la même raison.

```bash
mkdir -p bootstrap/cache storage/framework/{cache,sessions,views} storage/logs
docker compose up --build -d
```

Réponse : le contexte de build dépendait d'un état du disque de l'auteur qui n'a pas voyagé avec le code. C'est un défaut de reproductibilité, « ça marche chez moi ».

### 1.3

`curl -i localhost/` répond `500`. `docker compose logs app` ne montre que la ligne d'accès Apache ; le message `Table 'app_database.counters' doesn't exist` est dans le corps HTML de la réponse, parce que `APP_DEBUG=true` (une chose de plus à ne pas mettre en production). MySQL met une vingtaine de secondes à passer `healthy` ; avant, le corps dit `Connection refused`.

```bash
docker compose exec app php artisan migrate --force
```

`--seed` ne change rien ici, vous verrez pourquoi en 1.6.

Réponse : une étape de migration au démarrage, soit dans un entrypoint de `app`, soit dans un service one-shot qui dépend de `db` avec `condition: service_healthy`. Les deux se défendent.

### 1.4

`curl -i localhost/api/counter/count` renvoie une page HTML 404 signée `Server: Apache`. Laravel n'est jamais atteint : `public/.htaccess` manque, `mod_rewrite` est activé (`a2enmod rewrite` dans le Dockerfile) mais n'a aucune règle. Contournement sans rebuild : `curl localhost/index.php/api/counter/count`.

```bash
cp ../bloc1-docker/htaccess public/.htaccess
docker compose up --build -d
curl localhost/api/counter/add
```

Réponse : non, le bouton ne marchait pas. On le sait en lisant `resources/views/welcome.blade.php` (`$.get("/api/counter/add")`) et en testant l'URL au `curl`.

### 1.5

`down` puis `up` : compteur conservé, le volume `db_data` survit. `down -v` puis `up` : le volume est détruit, la base est vide, et l'API répond de nouveau 500 parce que le schéma a disparu avec la donnée.

Réponse : un conteneur est jetable, un volume survit au conteneur. Dans un cluster, un pod de base de données sans stockage persistant perd tout à chaque redémarrage.

### 1.6

`db:seed` lance `DatabaseSeeder`, dont le corps est une ligne commentée : il n'appelle jamais `CounterSeeder`. Zéro ligne insérée, et pourtant « Database seeding completed successfully ». S'il était branché, il planterait : `CounterFactory` remplit une colonne `counter` qui n'existe pas (la table a `count`), et le modèle `Counter` n'autorise aucune assignation de masse.

Après trois incréments : `count(*)` vaut 3, `sum(count)` vaut 3, l'API renvoie 3. Les deux chiffres coïncident parce que chaque ligne vaut 1. Leçon : un message de succès n'est pas une preuve, seule la donnée l'est.

## Bloc 2

### 2.1

`kubectl run` lancé quelques secondes après la création échoue avec `serviceaccount "default" not found` : le cluster finit de démarrer, le contrôleur qui crée le compte de service par défaut n'est pas encore passé, et le nœud est encore `NotReady`. Les deux faits sont liés au démarrage, pas l'un à l'autre ; en pratique, attendre le nœud `Ready` suffit.

```bash
kubectl wait node --all --for=condition=Ready --timeout=120s
```

Composants de `kube-system` : `kube-apiserver` (la porte d'entrée, tout passe par lui), `etcd` (l'état du cluster), `kube-scheduler` (choisit le nœud d'un pod), `kube-controller-manager` (fait converger l'état réel vers l'état désiré), `kube-proxy` (règles réseau des Services sur chaque nœud), `coredns` (DNS interne), `kindnet` (réseau entre pods). À part, dans le namespace `local-path-storage` : `local-path-provisioner` (stockage local). Le scheduler décide du nœud.

### 2.2

Un pod créé directement n'a pas de contrôleur. Personne ne surveille son état désiré, donc personne ne le recrée. Un ReplicaSet, via un Deployment, l'aurait fait.

### 2.3

Le Deployment est l'état désiré, les pods sont l'état réel, le contrôleur (le ReplicaSet, piloté par le Deployment) fait converger. Le segment du milieu du nom d'un pod est le hash du ReplicaSet. Le mot est réconciliation.

### 2.4

1.26 vers 1.27 : rollout propre, deux révisions dans l'historique. Vers `nginx:doesnotexist` : `rollout status` expire, les nouveaux pods sont en `ErrImagePull` puis `ImagePullBackOff`, trois anciens sur quatre continuent de servir : `READY` indique `3/4`, `AVAILABLE` indique `3`. `rollout undo` remet quatre pods en 1.27.

```bash
kubectl get deployment hello -o yaml | grep -A4 strategy
# type: RollingUpdate, maxSurge 25 %, maxUnavailable 25 %
```

Réponse : l'application n'a jamais été en panne. La stratégie de rolling update ne retire un ancien pod que quand un nouveau est prêt, et le nouveau ne l'a jamais été. Ça s'appelle un déploiement progressif. Ce n'est pas un rollback automatique : rien n'est revenu en arrière tout seul, c'est vous qui avez fait `undo`. Rendre ce mécanisme sensible à une erreur applicative, et pas seulement à une image absente, demande des sondes ; c'est dans le sujet.

### 2.5

`big` : `Pending` en quelques secondes, `describe` montre `0/1 nodes are available: 1 Insufficient memory`. Le scheduler ne trouve aucun nœud capable d'honorer la réservation : erreur de planification. `oom` : `Running` puis `OOMKilled` en quelques secondes, souvent la même seconde. Le processus dépasse sa limite, le kernel le tue : erreur d'exécution.

`limits` sans `requests` : Kubernetes recopie les limits dans les requests. `nolim.yaml` ne déclare que `limits.memory: 64Mi` ; le pod créé porte `requests.memory: 64Mi` en plus. Le pod tourne, mais le nœud est réservé à hauteur de la limite.
