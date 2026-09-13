# Bootstrap T-CLO-901 — Docker, puis un cluster Kubernetes sur votre poste

> Deux blocs, deux heures, onze exercices. Vous tapez, ça casse, vous diagnostiquez. Rien de ce que vous faites ici n'ira dans votre rendu. Tout ce que vous apprenez ici, vous le réutiliserez jusqu'en février.

Ce dépôt est autoportant : l'application, les manifestes, le script d'installation, les solutions. Rien à récupérer ailleurs. Lisez-le dans l'ordre, faites chaque exercice, répondez par écrit à chaque question dans un fichier `notes.md` que vous gardez. Les solutions sont dans [`solutions/`](solutions/README.md) : ouvrez-les quand vous avez cherché dix minutes, pas avant. Personne ne vérifie, c'est votre temps.

## Ce que ce bootstrap revoit

Six notions, et rien d'autre. Si vous les maîtrisez déjà, allez vite ; si un mot vous est inconnu, c'est là qu'il faut ralentir.

| Notion | Où | Ce que vous devez savoir dire à la fin |
|---|---|---|
| Image, conteneur, build reproductible | 1.1, 1.2 | Pourquoi une image qui se construit chez l'auteur peut ne pas se construire chez vous |
| Réseau et cycle de vie Compose | 1.1, 1.3, 1.4 | Qui parle à qui, par quel nom, sur quel port ; ce qu'un reverse proxy fait devant l'application |
| Persistance et volumes | 1.5, 1.6 | Ce qui survit à `down`, ce qui survit à `down -v`, et ce que ça implique pour une base de données |
| Pod, Deployment, réconciliation | 2.1, 2.2, 2.3 | La différence entre l'état désiré et l'état réel, et qui fait converger l'un vers l'autre |
| Déploiement progressif | 2.4 | Pourquoi une version cassée ne prend pas la main, et ce que ce n'est pas |
| Requests, limits, Pending, OOMKilled | 2.5 | Une erreur de planification contre une erreur d'exécution |

## Prérequis

- Docker Engine avec Compose v2 : `docker compose version` doit répondre. Sinon : <https://docs.docker.com/engine/install/>.
- `curl`, un terminal, un éditeur.
- Le bloc 2 installe `kind` et `kubectl` : deux binaires, pas de droits admin, script fourni.
- Git, pour cloner ce dépôt. C'est le seul téléchargement.

```bash
git clone https://github.com/hashbulla/t-clo-901-bootstrap.git
cd t-clo-901-bootstrap
```

L'application à manipuler est dans [`sample-app/`](sample-app/) : c'est celle du module, fournie par Epitech, reproduite ici telle quelle pour que le dépôt se suffise. Le lab AWS n'existe pas encore. Il se crée quand votre groupe existe sur l'Intra. Tout ce qui suit est local à votre machine.

---

## Bloc 1 — Docker, l'application telle qu'elle est aujourd'hui (60 min)

Placez-vous dans `sample-app/` (`cd sample-app`). Toutes les commandes du bloc 1 se lancent de là.

### 1.1 Lire avant de lancer (10 min)

Ouvrez `docker-compose.yaml` et `Dockerfile`. Sans rien lancer, répondez :

- Combien de services ? Lesquels parlent à lesquels, et par quel nom ?
- Sur quels ports de votre machine l'application sera-t-elle joignable, et par combien de chemins ?
- Où sont les mots de passe ?
- À quoi sert le volume `db_data` ?

**Question 1.1** — Citez trois choses dans ce fichier que vous refuseriez de mettre en production.

### 1.2 Construire (15 min)

```bash
docker compose up --build -d
```

Ça ne marche pas du premier coup. Lisez le message d'erreur en entier, remontez jusqu'à la ligne qui échoue dans le `Dockerfile`, corrigez sur votre poste, relancez. Interdit de modifier le `Dockerfile`.

Indice : `ls bootstrap`. Qu'est-ce que l'outil réclame, et qu'est-ce qui existe ?

**Question 1.2** — Pourquoi une image qui se construisait chez l'auteur ne se construit pas chez vous ? Quel est le nom de ce problème dans le métier ?

### 1.3 Atteindre (10 min)

```bash
docker compose ps
curl -i localhost/
```

Le code HTTP n'est pas celui que vous attendiez. Trouvez pourquoi avec `docker compose logs app`, corrigez avec une commande `docker compose exec`, sans rebuild.

Indice : l'application a besoin d'un schéma de base de données que personne n'a créé, et le `README.md` du sample-app nomme la commande. Si la base refuse la connexion, elle n'est pas encore prête : attendez `healthy` dans `docker compose ps`.

**Question 1.3** — Quelle étape manque au `docker-compose.yaml` pour que ce soit automatique ? Où la mettriez-vous ?

### 1.4 L'API (10 min)

```bash
curl -i localhost/api/counter/count
curl localhost/api/counter/add
```

Encore un problème, et ce n'est pas le même. Regardez qui répond : l'en-tête `Server`. Quand vous avez compris quel composant échoue et pourquoi, le fichier manquant est dans [`bloc1-docker/htaccess`](bloc1-docker/htaccess), à la racine du dépôt : copiez-le au bon endroit sous le bon nom, rebuild, puis faites incrémenter le compteur trois fois.

**Question 1.4** — Le bouton de la page `localhost/` appelle `/api/counter/add`. Avant votre correctif, marchait-il ? Comment le saviez-vous sans cliquer ?

### 1.5 Où va la donnée (10 min)

Notez la valeur du compteur. Puis :

```bash
docker compose down
docker compose up -d
curl localhost/api/counter/count
```

Puis :

```bash
docker compose down -v
docker compose up -d
curl -i localhost/api/counter/count
```

**Question 1.5** — Expliquez la différence entre les deux résultats en une phrase. Qu'est-ce que ça implique pour une base de données dans un cluster ?

### 1.6 Sortie du bloc (5 min)

```bash
docker compose exec db mysql -uapp_user -papp_password app_database -e 'select count(*), sum(count) from counters;'
docker compose down
```

Comparez avec ce que renvoie l'API.

---

## Bloc 2 — Un cluster jetable sur votre poste (65 min)

### Installer

Revenez à la racine du dépôt (`cd ..`). Linux x86_64 :

```bash
bash bloc2-kind/install.sh
export PATH="$HOME/.local/bin:$PATH"
kind version && kubectl version --client
```

Lisez le script avant de le lancer : douze lignes, deux `curl`, un `chmod`.

macOS, Windows, ARM : <https://kind.sigs.k8s.io/docs/user/quick-start/#installation> et <https://kubernetes.io/docs/tasks/tools/>.

### 2.1 Créer et regarder (10 min)

```bash
kind create cluster --name bootstrap
kubectl get nodes
kubectl run web --image=nginx:1.26
```

La troisième commande échoue si vous allez vite. Lisez l'erreur, regardez le statut du nœud, attendez la bonne condition avec `kubectl wait`, réessayez. Puis :

```bash
kubectl get pods -A
```

**Question 2.1** — Nommez les composants du namespace `kube-system` et dites en un mot à quoi sert chacun. Lequel décide sur quel nœud va un pod ?

### 2.2 Un pod nu (10 min)

```bash
kubectl expose pod web --port=80
kubectl port-forward svc/web 8080:80 &
sleep 2
curl -i localhost:8080
kill %1
kubectl delete pod web
kubectl get pods
```

**Question 2.2** — Le pod ne revient pas. Qui aurait dû le recréer, et pourquoi personne ne l'a fait ?

### 2.3 Un Deployment (10 min)

```bash
kubectl create deployment hello --image=nginx:1.26 --replicas=2
kubectl expose deployment hello --port=80
kubectl get pods -l app=hello -o wide
kubectl delete pod -l app=hello
kubectl get pods -l app=hello
kubectl scale deployment hello --replicas=4
kubectl get pods -l app=hello
```

Lisez les noms des pods : d'où vient le segment du milieu ?

**Question 2.3** — Entre un pod et un Deployment, lequel est l'état désiré, lequel l'état réel ? Qui fait converger l'un vers l'autre ?

### 2.4 Mettre à jour sans couper, puis rater (15 min)

```bash
kubectl set image deployment/hello nginx=nginx:1.27
kubectl rollout status deployment/hello
kubectl rollout history deployment/hello
```

Puis, exprès :

```bash
kubectl set image deployment/hello nginx=nginx:doesnotexist
kubectl rollout status deployment/hello --timeout=30s
kubectl get pods -l app=hello
kubectl get deployment hello
```

Regardez combien de pods servent encore, dans quel état sont les nouveaux, et ce que dit la colonne `AVAILABLE`. Vérifiez au `curl` via un `port-forward` sur `svc/hello`. Puis :

```bash
kubectl rollout undo deployment/hello
kubectl rollout status deployment/hello
```

Indice : `kubectl get deployment hello -o yaml | grep -A4 strategy`.

**Question 2.4** — Pendant que la version cassée « se déployait », l'application était-elle en panne ? Qu'est-ce qui a empêché la bascule ? Ce comportement a-t-il un nom ? Est-ce un « rollback automatique » ?

### 2.5 Trop demander, trop peu autoriser (15 min)

Lisez [`bloc2-kind/big.yaml`](bloc2-kind/big.yaml) et [`bloc2-kind/oom.yaml`](bloc2-kind/oom.yaml) avant de les appliquer : dites-vous ce que chacun va faire.

```bash
kubectl apply -f bloc2-kind/big.yaml
kubectl get pod big
kubectl describe pod big | tail -5
```

```bash
kubectl apply -f bloc2-kind/oom.yaml
kubectl get pod oom -w
```

`Ctrl-C` quand le statut change.

**Question 2.5** — Les deux pods ont échoué pour des raisons opposées. Laquelle est une erreur de planification, laquelle une erreur d'exécution ? Que se passe-t-il si vous mettez des `limits` sans `requests` ? Testez-le.

### 2.6 Nettoyer (2 min)

```bash
kind delete cluster --name bootstrap
```

Tout a disparu. C'est voulu. Vous savez le recréer en une commande.

---

## Auto-évaluation (5 min)

Trois lignes dans `notes.md`, puis à l'oral :

1. Une chose que je sais faire sans regarder.
2. Une chose que j'ai faite ce matin mais que je ne saurais pas refaire seul.
3. Une chose dont je ne sais pas encore ce que c'est, parmi les mots entendus aujourd'hui.

Gardez ce fichier. Relisez-le le jour de la soutenance.

## Pour aller plus loin, seuls

Les sections suivantes du bootstrap national ne sont pas couvertes ici : bases de l'orchestrateur en profondeur (sondes de vie et de disponibilité), empaquetage avec Helm et Kustomize, secrets, stockage persistant, contrôle d'admission. Vous les rencontrerez dans le sujet. Trois lectures qui suffisent pour démarrer :

- Kubernetes, concepts : <https://kubernetes.io/docs/concepts/> (Workloads, puis Configuration)
- kind, guide utilisateur : <https://kind.sigs.k8s.io/docs/user/quick-start/>
- Compose, référence du fichier : <https://docs.docker.com/reference/compose-file/>

---

Victor Poiraud, intervenant T-CLO-901, Epitech Rennes 2026-2027. Commandes vérifiées le 13/09/2026 sur Linux x86_64, kind v0.33.0, Kubernetes v1.37.0, Docker Compose v2. Contenu du dépôt sous licence MIT ; `sample-app/` appartient à Epitech et n'est reproduit ici qu'à des fins pédagogiques pour le module.
