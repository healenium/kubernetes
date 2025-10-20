# Руководство по тестированию Healenium Helm Chart

## ✅ Статус публичного репозитория

**Публичный Helm репозиторий работает!** 🎉

- **URL**: https://healenium.github.io/kubernetes
- **Текущая версия**: 0.1.3
- **Статус GitHub Pages**: ✅ Активен (HTTP 200)

---

## 🧪 Тестирование без Kubernetes кластера

Если у вас нет запущенного кластера, можно проверить репозиторий в dry-run режиме:

### 1. Проверить доступность index.yaml

```bash
curl https://healenium.github.io/kubernetes/index.yaml
```

Должен вернуть YAML файл с информацией о chart.

### 2. Добавить Helm репозиторий

```bash
helm repo add healenium https://healenium.github.io/kubernetes
helm repo update
```

### 3. Найти доступные charts

```bash
helm search repo healenium
```

Вывод должен быть примерно таким:
```
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
healenium/healenium     0.1.3           0.1.0           Healenium Helm chart for Kubernetes - Self-hea...
```

### 4. Посмотреть информацию о chart

```bash
helm show chart healenium/healenium
```

### 5. Посмотреть values

```bash
helm show values healenium/healenium
```

### 6. Dry-run установка (без реального применения)

```bash
helm install test-healenium healenium/healenium --dry-run --debug
```

Это покажет все манифесты Kubernetes которые будут созданы, но не применит их.

---

## 🚀 Тестирование с Minikube (полная установка)

Если вы хотите протестировать реальную установку:

### Шаг 1: Запустить Minikube

```bash
minikube start --memory=4096 --cpus=2
```

### Шаг 2: Включить Ingress

```bash
minikube addons enable ingress
```

### Шаг 3: Добавить Helm репозитории

```bash
# Healenium
helm repo add healenium https://healenium.github.io/kubernetes

# Bitnami для PostgreSQL
helm repo add bitnami https://charts.bitnami.com/bitnami

# Docker Selenium для Selenium Grid (опционально)
helm repo add docker-selenium https://www.selenium.dev/docker-selenium

# Обновить
helm repo update
```

### Шаг 4: Установить PostgreSQL

```bash
helm install db bitnami/postgresql \
  --set global.postgresql.auth.postgresPassword=admin \
  --set global.postgresql.auth.username=healenium_user \
  --set global.postgresql.auth.password=YDk2nmNs4s9aCP6K \
  --set global.postgresql.auth.database=healenium \
  --set primary.persistence.enabled=true
```

### Шаг 5: Установить Selenium Grid (опционально, только для Healenium-Proxy)

```bash
helm install selenium-grid docker-selenium/selenium-grid
```

### Шаг 6: Установить Healenium

**С Proxy (для всех языков Selenium):**
```bash
helm install healenium healenium/healenium
```

**Без Proxy (только для Java/healenium-web):**
```bash
helm install healenium healenium/healenium --set hlmproxy.enable=false
```

**С кастомными значениями:**
```bash
helm install healenium healenium/healenium -f my-values.yaml
```

### Шаг 7: Проверить статус установки

```bash
# Посмотреть pods
kubectl get pods

# Посмотреть services
kubectl get services

# Посмотреть Helm releases
helm list

# Подробная информация о release
helm status healenium
```

### Шаг 8: Получить доступ к Healenium

```bash
# Получить IP minikube
minikube ip

# Добавить в /etc/hosts
echo "$(minikube ip) healenium.k8s.com" | sudo tee -a /etc/hosts

# Открыть в браузере
open http://healenium.k8s.com
```

---

## 🧹 Очистка после тестирования

```bash
# Удалить Healenium
helm uninstall healenium

# Удалить Selenium Grid (если устанавливали)
helm uninstall selenium-grid

# Удалить PostgreSQL
helm uninstall db

# Остановить Minikube
minikube stop

# Или полностью удалить
minikube delete
```

---

## 📊 Проверка различных версий

```bash
# Посмотреть все доступные версии
helm search repo healenium -l

# Установить конкретную версию
helm install healenium healenium/healenium --version 0.1.3

# Обновить до новой версии
helm upgrade healenium healenium/healenium --version 0.1.4
```

---

## 🔧 Troubleshooting

### Проблема: helm repo add выдает ошибку

**Решение:**
```bash
# Проверить что URL доступен
curl -I https://healenium.github.io/kubernetes/index.yaml

# Удалить и добавить заново
helm repo remove healenium
helm repo add healenium https://healenium.github.io/kubernetes
helm repo update
```

### Проблема: Chart не находится

**Решение:**
```bash
# Обновить репозиторий
helm repo update healenium

# Очистить кэш
rm -rf ~/.cache/helm
helm repo update
```

### Проблема: Pods не запускаются

**Решение:**
```bash
# Проверить логи pod
kubectl logs <pod-name>

# Описание pod для деталей
kubectl describe pod <pod-name>

# Проверить events
kubectl get events --sort-by='.lastTimestamp'
```

---

## 📦 Кастомизация установки

Создайте файл `my-values.yaml`:

```yaml
hlmbackend:
  tag: 3.4.3
  resources:
    requests:
      memory: 2048Mi
      cpu: 500m

postgresql:
  endpoint:
    address: my-postgresql.default.svc.cluster.local
    password: my-secure-password

hlmproxy:
  enable: true
  environment:
    selenium_server_url: http://my-selenium-hub:4444/

ingress:
  enable: true
  hosts:
    - healenium.example.com
```

Затем установите:
```bash
helm install healenium healenium/healenium -f my-values.yaml
```

---

## ✅ Успешная установка

После успешной установки вы должны увидеть примерно такой вывод:

```
NAME: healenium
LAST DEPLOYED: Mon Oct 20 16:00:00 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
```

И pods в статусе Running:
```
kubectl get pods
NAME                                    READY   STATUS    RESTARTS   AGE
healenium-hlm-backend-xxx              1/1     Running   0          2m
healenium-hlm-selector-imitator-xxx    1/1     Running   0          2m
healenium-hlm-proxy-xxx                1/1     Running   0          2m  # если proxy включен
db-postgresql-0                         1/1     Running   0          5m
```

---

## 📚 Дополнительные ресурсы

- **GitHub Repository**: https://github.com/healenium/kubernetes
- **Healenium Documentation**: https://healenium.io
- **Helm Documentation**: https://helm.sh/docs/
- **Issue #8**: https://github.com/healenium/kubernetes/issues/8

---

**Все работает! Публичный Helm репозиторий готов к использованию!** 🎉

